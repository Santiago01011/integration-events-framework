# Pilot Plan — andromaco-qa (Week 1) & Code-Side Review

Division of labor: **specialized agents** execute the org-side install and operate the pilot. **The framework author** (this repo's side) reviews performance and implementation one week after install, with zero write access to the pilot org.

## Phase 0 — Setup (org-side agents)

1. Install **core 1.5.1-1** (`04tak000000fkzlAAA`) in andromaco-qa via `sf package install --no-prompt`. Plugins optional; TopErrors + SeverityDonut recommended, Calendar skipped.
2. Assign permission sets **before** anyone opens the dashboard: `Integration_Dashboard_Admin` (pilot owner), `Integration_Dashboard_Read` (viewers). Denied users get a friendly card + a single `DASHBOARD_ACCESS_DENIED` event — this is expected behavior, not an incident.
3. Register taxonomy (Definition rows): `REVIEWS` (REST, Inbound), `CASE_B2C_SYNC` (REST, Outbound). Evaluation Rules for: `REVIEW_APPROVED`→SUCCESS, `REVIEW_REJECTED`→INFO, `REVIEW_INGEST_FAILED`→FATAL, `REVIEW_INGEST_EXCEPTION`→ERROR, `CASE_SYNC_FAILED`→ERROR, `CASE_SYNC_EXCEPTION`→ERROR.
4. Create `IntegrationEventsDispatcher` adapter (thin, 5-arg, framework-present flag + debug fallback) and switch `IntegrationEventsConnector` Option B to delegate to it. Map dotted event names (`REVIEW.APPROVED`) to `UPPER_SNAKE` observation types (`REVIEW_APPROVED`). Business code untouched.
5. Update `IntegrationEventsConnectorTest`; assert via `Integration_Log__c` after `Test.stopTest()` (platform events cannot be SOQL'd).
6. Schedule `IntegrationLogCleanupBatch` daily (default 30-day retention).
7. E2E smoke: emit one test event per code; verify log rows + dashboard rendering + severity mapping.

## Phase 1 — Week 1 telemetry (org-side agents, capture daily)

- Daily `Integration_Log__c` creation counts, split by `IntegrationCode__c` and `ObservationType__c`.
- Platform event publish counts vs org allocation (Setup → Platform Event usage / `EventRelayMetric` if available).
- Apex limits from handler/publisher logs: CPU, heap, SOQL/DML per transaction on peak days.
- Scheduled job health: `IntegrationLogCleanupBatch` runs, failures.
- Unexpected Apex exceptions (any source touching the framework).
- User feedback: severity usefulness, noise level, false positives, dashboard responsiveness.
- Count of `DASHBOARD_ACCESS_DENIED` events (each = a non-permitted user found the dashboard).

## Phase 2 — Code-side review (author, 1 week after install)

Reviewed against real pilot data, evidence from the repo at `main`:

1. **Volume vs design**: actual events/day vs platform-event allocation headroom; verify summary-emission guidance was followed on batch paths (`B2CSyncNightlyRetry` emits per-chunk, not per-row).
2. **Query performance at real volume**: `IntegrationHealthSelector` pagination plans on grown `Integration_Log__c`; check whether custom indexes on `IntegrationCode__c` / `ObservationType__c` / `CreatedDate` are warranted.
3. **Publisher hot path**: real emit patterns vs bulk-safety assumptions; kill-switch coverage for any noisy code.
4. **Realtime behavior**: EMP update cadence with real concurrent users.
5. **Data growth projection**: storage trend, retention batch adequacy; evaluate archival/big-object threshold.
6. **Severity effectiveness**: rule hit/miss ratio; observation types falling to default severity; retune proposals (CMDT-only, no core deploys).
7. **Defect triage**: pilot findings classified core-fix vs consumer-adapter-fix; core fixes go through the pipeline (feature → dev PR → main PR).
8. **Deferred backlog check**: core→reference-card static import, `@track` sweep, retention scheduling UX.

### Decision gates

| Gate | When   | Criteria                                                       | Action                                                                   |
| ---- | ------ | -------------------------------------------------------------- | ------------------------------------------------------------------------ |
| A    | Day 3  | No allocation breaches, no lost events, no P1 defects          | Continue pilot                                                           |
| B    | Day 7  | Volume within limits, severity useful, storage projection sane | Recommend promote of 1.5.x for wider rollout, or a 1.5.2 fix batch first |
| Exit | Day 7+ | Pilot success declared                                         | Handoff to permanent operation; document ops runbook                     |

## Non-negotiables

- Pilot org is QA only; **no promoted packages**, no production installs.
- Core changes during the pilot only for P1 defects, via the PR pipeline.
- All telemetry evidence must be citable (SOQL outputs, log extracts) — the code review judges data, not anecdotes.
