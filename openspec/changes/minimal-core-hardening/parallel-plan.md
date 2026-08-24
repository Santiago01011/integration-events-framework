# Parallel Execution Runbook — minimal-core-hardening

> One-page orchestrator guide for the next session (post model-switch). Topology: `D7 → DN → fork{A,B} → join → integrator`. Two background agents run in isolated `git worktree`s; a final integrator merges and validates. Do NOT launch apply until owner switches model.

## Prerequisites

- Branch: `feature/core-next` (source-only; no package versions created)
- Baseline: `git fetch origin && git checkout feature/core-next && git pull --ff-only && git status --porcelain` must be clean
- Tooling: `npm run test:unit`, `npm run lint`, `npm run prettier:verify` must be executable locally; Apex org-deferred verifications stay flagged for CI

## Step 0 — Sequential Prelude (no worktree, runs on `feature/core-next`)

Run directly on `feature/core-next` before forking. Two slices, pushed before parallel window.

| Slice      | Tasks            | Gate                                                                                                                                                                                                                  |
| ---------- | ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D7 hygiene | 1.1–1.9          | `npx sfdx-lwc-jest force-app/integration-logs-framework/lwc` + greps: `ihdTrendIndicator` 0, `console.log` 0, `_parseContextData` single impl                                                                         |
| DN rename  | 2.1–2.6 (ATOMIC) | `npm run test:unit` + `grep -ri ihd force-app sfdx-project.json config translations` ⇒ 0 outside `docs/archive/**`, `docs/architecture-study/**` + `grep -r Plugging` ⇒ 0 + `npm run lint && npm run prettier:verify` |

```bash
# After each slice, commit and push so worktrees fork from the correct baseline
git push origin feature/core-next
```

## Step 1 — Create Worktrees (fork)

```bash
git worktree add ../wt-a-d6 -b wip/minimal-core-d6 feature/core-next
git worktree add ../wt-b-d1early -b wip/minimal-core-d1early feature/core-next
git worktree list  # verify: 3 worktrees (main + A + B)
```

## Step 2 — Launch 2 Background Agents (parallel)

Launch both concurrently. Each agent's working directory is its worktree path.

### Agent A — `Worker A: D6 Introspection` (`../wt-a-d6`, branch `wip/minimal-core-d6`)

**Prompt slice (copy verbatim):**

> You are Worker A — D6 Composition Introspection. Worktree: `../wt-a-d6` (branch `wip/minimal-core-d6`, forked from `feature/core-next` after D7+DN). Implement ONLY tasks 3.1–3.4 from `openspec/changes/minimal-core-hardening/tasks.md` (Parallel Window — Branch A). Exact scope: `force-app/integration-logs-framework/classes/IEF_PluginRegistry.cls` (add `Resolution{instance,status,reason}` + `resolve(IEF_Plugin__mdt)` — statuses ACTIVE/ACTIVE_LWC/FAILED/ORPHAN, orphan via `Type.forName==null`, migrate `getInstance` callers `IEF_SObjectHandler`/`CallableIEF`/controller; no `System.debug`/silent null), `IntegrationHealthWrappers.cls` (add `PluginCompositionEntry`), `IntegrationHealthController.cls` (add `getCompositionInfo()` — do NOT delete aggregates; deletions belong to integrator), `CallableIEF.cls` (additive `getCompositionInfo` action), new CI test class for idempotent registration (3.3), `permissionsets/Integ_PluginIntrospection_Read` + `Permissions.md` (3.4). Do NOT touch `force-app/ief-plugin-*`, `docs/plugin-contract-versioning.md`, reference health card (4.5), or `Contract_Version__c`/`IEF_PluginContract` (D2A). Verify with `npm run lint` + static shape greps for `getCompositionInfo`/`Resolution`. Commit in your worktree when green. Do NOT push to `feature/core-next` or merge — integrator will merge your branch.

**File ownership (must stay inside):**

- `force-app/integration-logs-framework/classes/IEF_PluginRegistry.cls`
- `force-app/integration-logs-framework/classes/IntegrationHealthWrappers.cls`
- `force-app/integration-logs-framework/classes/IntegrationHealthController.cls` (additive only)
- `force-app/integration-logs-framework/classes/CallableIEF.cls`
- `force-app/integration-logs-framework/classes/IEF_SObjectHandler.cls`
- `force-app/integration-logs-framework/classes/*Test.cls` (only the CI test class for 3.3)
- `force-app/integration-logs-framework/permissionsets/Integ_PluginIntrospection_Read.*`
- `Permissions.md`

### Agent B — `Worker B: D1-early + Parallel Docs` (`../wt-b-d1early`, branch `wip/minimal-core-d1early`)

**Prompt slice (copy verbatim):**

> You are Worker B — D1-early Plugin Providers + Parallel Docs. Worktree: `../wt-b-d1early` (branch `wip/minimal-core-d1early`, forked from `feature/core-next` after D7+DN). Implement ONLY tasks 4.1, 4.2, 4.3, 5.3 (draft), and 1.9′ from `openspec/changes/minimal-core-hardening/tasks.md` (Parallel Window — Branch B). Exact scope: `force-app/ief-plugin-severity/main/default/classes/IEF_SeverityCardPlugin.cls` (new, `implements IEF_CardPlugin`, `@AuraEnabled getCardData(filters)` — move selector logic), `force-app/ief-plugin-severity/main/default/customMetadata/IEF_Plugin.Severity_Card.md-meta.xml` (`ApexClassName__c` N/A→plugin class), `force-app/ief-plugin-severity/main/default/lwc/iefSeverityCardImpl/*` + `iefSeverityBreakdown/*` + `iefSeverityShell/*` (import `c/iefPluginContext`, swap Apex import to own-package `getCardData`); same for `ief-plugin-toperrors` (`IEF_TopErrorsCardPlugin.cls` + trend→`entry.trend` + its LWCs + CMDT row); plus `docs/plugin-contract-versioning.md` draft (additive-only evolution, minor/major semantics) so the integrator has the guide, and finalize C3 ApexDocs on the new providers (task 1.9′). Do NOT touch `force-app/integration-logs-framework/classes/IEF_PluginRegistry.cls`, `IntegrationHealthWrappers.cls`, `IntegrationHealthController.cls`, `CallableIEF.cls`, `IEF_SObjectHandler.cls`, `Permissions.md` introspection set, reference health card (4.5), core deletions (4.4), or `IEF_PluginContract`/`Contract_Version__c` field (D2A core). Verify with `npx sfdx-lwc-jest` for card LWCs (existing tests unchanged + new provider path) and static checks. Commit in your worktree when green. Do NOT push or merge.

**File ownership (must stay inside):**

- `force-app/ief-plugin-severity/**`
- `force-app/ief-plugin-toperrors/**`
- `docs/plugin-contract-versioning.md` (draft)
- ApexDocs on `IEF_SeverityCardPlugin.cls` / `IEF_TopErrorsCardPlugin.cls` (C3 filter docs)

> Both agents run concurrently. Poll with `git worktree list` and check each worktree's `git log --oneline -3` and `git status`.

## Step 3 — Join (merge A then B into `feature/core-next`)

Run only after both workers report green (tests + lints pass in their worktrees).

```bash
git checkout feature/core-next
git merge --no-ff wip/minimal-core-d6 -m "merge: D6 composition introspection (Worker A)"
# Expected: clean (A touched only core registry files)

git merge --no-ff wip/minimal-core-d1early -m "merge: D1-early plugin providers + parallel docs (Worker B)"
# Expected: clean (B touched only ief-plugin-* + docs — disjoint from A)

git push origin feature/core-next  # checkpoint
```

**If a merge reports a conflict:** abort (`git merge --abort`), run `git diff --name-only` against `tasks.md` Worktree File Ownership table — a worker touched a file outside its allowed set. Move the stray change to the correct worktree/integrator and re-merge.

## Step 4 — Final Integrator Agent (join → `../wt-integrator`)

```bash
git worktree add ../wt-integrator -b wip/minimal-core-integrator feature/core-next
```

**Prompt slice for integrator (copy verbatim):**

> You are the Final Integrator — D1-late + D2A + Final Gate. Worktree: `../wt-integrator` (branch `wip/minimal-core-integrator`, forked from `feature/core-next` AFTER both Worker A (D6) and Worker B (D1-early) have been merged). Implement ONLY tasks 4.4, 4.5, 5.1, 5.2, 5.3′ (finalize), and 5.4 from `openspec/changes/minimal-core-hardening/tasks.md` (Integrator phase). Exact scope: delete `getSeverityCounts`/`getTopErrorIntegrations`/`getHourlyTrend`/`getLogCountsByIntegrationCode` from `IntegrationHealthController`/`IntegrationHealthService`/`IntegrationHealthSelector` (4.4 — depends on B's providers); create reference health card `IEF_RegistryHealthCardPlugin.cls` + `lwc/iefRegistryHealthCard/` + `lwc/iefRegistryHealthShell/` + CMDT row `IEF_Plugin.Plugin_Registry_Health` (CARD, `CardLocation__c='summary'`) with RED jest mocking composition entries (4.5 — dogfoods Work A’s `getCompositionInfo`); create `objects/IEF_Plugin__mdt/fields/Contract_Version__c.field-meta.xml` (default 1.0) + `classes/IEF_PluginContract.cls` (`SUPPORTED_MAJOR=1`) (5.1); add major-mismatch check INSIDE `IEF_PluginRegistry.resolve()` (5.2 — extends Worker A’s `resolve()` → `SKIPPED_VERSION_MISMATCH` + FRAMEWORK_INTERNAL event + placeholder; never throw) with RED jest for skipped plugin; finalize/verify `docs/plugin-contract-versioning.md` (5.3′); then run the full final gate (5.4): `npm run test:unit && npm run lint && npm run prettier:verify` plus the success-criteria greps in `tasks.md` Worktree Isolation & Merge Strategy. Commit, merge back to `feature/core-next`, and push. Apex org-deferred checks stay flagged for CI.

**File ownership (integrator):**

- `force-app/integration-logs-framework/classes/IntegrationHealthController.cls` (deletions)
- `force-app/integration-logs-framework/classes/IntegrationHealthService.cls`
- `force-app/integration-logs-framework/classes/IntegrationHealthSelector.cls`
- `force-app/integration-logs-framework/classes/IEF_RegistryHealthCardPlugin.cls` + `lwc/iefRegistryHealthCard/` + `lwc/iefRegistryHealthShell/` + `customMetadata/IEF_Plugin.Plugin_Registry_Health.md-meta.xml`
- `force-app/integration-logs-framework/objects/IEF_Plugin__mdt/fields/Contract_Version__c.field-meta.xml`
- `force-app/integration-logs-framework/classes/IEF_PluginContract.cls`
- `force-app/integration-logs-framework/classes/IEF_PluginRegistry.cls` (patch `resolve()` with version guard)
- `docs/plugin-contract-versioning.md` (finalize)

**Integrator validation (must be green before push — from tasks.md):**

```bash
npm run test:unit && npm run lint && npm run prettier:verify
! grep -rn "getSeverityCounts\|getTopErrorIntegrations\|getHourlyTrend\|getLogCountsByIntegrationCode" force-app/integration-logs-framework/classes
! grep -ri "ihd" force-app sfdx-project.json config --exclude-dir=archive | grep -v "docs/archive" | grep -v "docs/architecture-study"
! grep -r "Plugging" sfdx-project.json config
! grep -rn "System\.debug" force-app/integration-logs-framework/classes/IEF_PluginRegistry.cls
test -f force-app/integration-logs-framework/classes/IEF_RegistryHealthCardPlugin.cls
test -f force-app/integration-logs-framework/objects/IEF_Plugin__mdt/fields/Contract_Version__c.field-meta.xml
test -f docs/plugin-contract-versioning.md
```

## Step 5 — Merge integrator and cleanup

```bash
git checkout feature/core-next
git merge --no-ff wip/minimal-core-integrator -m "merge: D1-late + D2A + final gate (integrator)"
git push origin feature/core-next
git worktree remove ../wt-a-d6
git worktree remove ../wt-b-d1early
git worktree remove ../wt-integrator
git branch -d wip/minimal-core-d6 wip/minimal-core-d1early wip/minimal-core-integrator
```

## Risks & Guardrails

- **Do NOT launch Worker A/B before D7+DN are pushed.** DN renames every `IHD`→`IEF`; forking earlier would double-rename.
- **File-set violations are the only expected conflict source.** Enforce ownership tables strictly.
- **Apex tests are org-deferred.** Local gates are jest + lint + prettier + greps; Apex static shape checks (`grep` for method names, enum constants) substitute locally.
- **Do NOT launch apply until owner switches model** — this runbook is the handoff artifact for that next session.

## Artifact Index

- `openspec/changes/minimal-core-hardening/tasks.md` — task list with `[Worktree: ...]` annotations + Parallel Execution Plan (mermaid + ownership + merge strategy)
- `openspec/changes/minimal-core-hardening/parallel-plan.md` — this runbook
- `openspec/changes/minimal-core-hardening/proposal.md` / `spec.md` / `design.md` — unchanged (read before planning)
