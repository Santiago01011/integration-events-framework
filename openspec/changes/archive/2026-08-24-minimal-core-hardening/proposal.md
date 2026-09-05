# Proposal: Minimal Core Hardening

## Intent

Turn the battle-tested internal framework into a distributable, org-agnostic product: a minimal standalone core hardened for ecosystem **resilience** (failure containment, degradation, version tolerance) and **adaptability** (plugin seams, contract versioning, introspection). This first slice establishes a trustworthy baseline, then completes the Apex card seam, then adds a contract version guard.

## Scope

### In Scope (backlog sequence D7 → DN → D6 → D1 → D2A; Part 04 order with DN inserted after hygiene)

- **D7 hygiene batch**: remove dead core code (`ihdTrendIndicator`, phantom severity/top-errors fetches, `message.gridSpan` read, stray `console.log`); fix placeholder label bug; align filter params (C3); move evaluation-rule CMDT rows out of the calendar package (C8); unify layout convention `lwc/` (C9); dedup `_parseContextData` via shared core module (C7); fix publish exception type + replace hardcoded plugin-type strings with enum (C11).
- **DN IEF naming unification (owner-locked)**: rename everything to the IEF namespace — Apex classes (`IHD_*` → `IEF_*`, `CallableIHD` → `CallableIEF`), `IHD_Plugin__mdt` → `IEF_Plugin__mdt` as a clean source-level breaking change (greenfield-only installs; no data-migration class), LWC bundles (`ihd*` → `ief*`, `integrationHealthDashboard` → `iefDashboard`), plugin package directories `ihd-plugin-*` → `ief-plugin-*` and package names `IEF_Plugging_*` → `IEF_Plugin_*` (typo fix), custom permission/labels/translations; zero `ihd`/`IHD` references outside a docs-only allowlist. Breaking renames ride the already-deferred next major package version.
- **D6 composition introspection**: surface plugin instantiation failures (replace silent debug-log + cached-null in `IHD_PluginRegistry.getInstance`) with an effective-composition view (resolved rows, order, failures + reasons).
- **D1 core extraction**: move severity/top-errors/trend aggregate queries out of `IntegrationHealthController/Service/Selector` into plugin packages as real `IHD_CardPlugin` providers (fixes C1 + C2, completes the three-role seam). Recommend **Option B** — core ships one reference card provider proving the seam end-to-end.
- **D2A contract versioning**: `Contract_Version__c` CMDT field + loud skip-on-mismatch with logged reason.

### Out of Scope

- D3 LWC lazy loading (`import()`) — deferred until real perf data.
- D4 registry-enforced LMS actions — docs classification only if touched at all.
- D5 capability enforcement — docs/normative tier only.
- Agentforce plugin migration (parked branch stays parked).
- Package version creation + dependency pin updates (requires DevHub; none authenticated — deferred and flagged).
- Removing speculative `IHD_ServicePlugin` / `IHD_FieldPlugin` surfaces (future decision).

## Capabilities

> Research: `openspec/specs/` is empty — first SDD change in this repo.

### New Capabilities

- `plugin-composition-introspection`: resolved registry rows, ordering, and instantiation failures visible to admins; silent-null caching eliminated.
- `contract-versioning`: contract version declaration on plugin registry rows and loud, logged skip on mismatch.
- `ief-naming-unification`: single IEF namespace across Apex, CMDT, LWC, and packages — clean source-level rename for greenfield installs, no data migration.

### Modified Capabilities

None.

## Approach

Hygiene first (no contract change, low risk), introspection second (makes everything after verifiable in the field), then the C1/C2 extraction completing the three-role seam, then the D2A version guard. Strict TDD applies to LWC (`npm run test:unit`); Apex verified by static review and deferred to org/CI.

## Affected Areas

| Area                                                        | Impact   | Description                                                                                                              |
| ----------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------ |
| `force-app/integration-logs-framework/` (core)              | Modified | Dead-code removal; aggregate methods extracted; registry introspection; `Contract_Version__c` field; shared parse module |
| `force-app/ihd-plugin-severity/` → `ief-plugin-severity/`   | Modified | New Apex card provider; boilerplate dedup; DN rename                                                                     |
| `force-app/ihd-plugin-toperrors/` → `ief-plugin-toperrors/` | Modified | New Apex card provider; DN rename                                                                                        |
| `force-app/ihd-plugin-calendar/` → `ief-plugin-calendar/`   | Modified | Evaluation-rule CMDT rows relocated out; DN rename                                                                       |

## Risks

| Risk                                                       | Likelihood | Mitigation                                                                |
| ---------------------------------------------------------- | ---------- | ------------------------------------------------------------------------- |
| Apex tests unrunnable locally (no org authed)              | High       | Static review + explicit flag for CI/org verification                     |
| Packaging / dependency pin updates need DevHub             | High       | Defer package version creation; source-only slice                         |
| D1 moves CMDT rows — install/uninstall ordering edge cases | Medium     | Define removal semantics per registry row; introspection surfaces orphans |
| Scope creep across four backlog decisions                  | Medium     | Chained PR slices per work unit (hygiene → introspection → D1 → D2A)      |

## Rollback Plan

Source-only changes on `feature/core-next`; revert per work unit via git. No package versions are created in this slice, so no org-level rollback is needed.

## Dependencies

- None external. DevHub only for deferred packaging steps.

## Success Criteria

- [ ] Zero plugin-specific aggregate methods remain in core (`getSeverityCounts`, `getTopErrorIntegrations`, trend).
- [ ] Zero `ihd`/`IHD` references in source after the rename sweep (docs-only allowlist: `docs/archive/**`, `docs/architecture-study/**`).
- [ ] Every shipped contract class has ≥1 real provider AND a real consumer (three-role rule).
- [ ] Plugin instantiation failures are surfaced with reason, never silently cached as null.
- [ ] Uninstalling the calendar plugin leaves pipeline evaluation config intact.
- [ ] `npm run test:unit`, `npm run lint`, `npm run prettier:verify` all green.

## Proposal question round (auto mode — assumptions needing owner review)

1. **D1 A vs B**: Option B (core ships one reference card) recommended per the three-role rule — confirm?
2. **Contract version baseline**: stamp current contract as `1.0` with core 1.5.0?
3. **Introspection surface**: Apex data method + admin LWC panel now, or Apex-only this slice?
