# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] — minimal-core-hardening

### Added

- D6 (upcoming): `IEF_PluginRegistry.resolve()` → `Resolution{instance,status,reason}` and `IntegrationHealthController.getCompositionInfo()` / `CallableIEF` `getCompositionInfo` action for effective composition visibility (statuses: `ACTIVE`, `ACTIVE_LWC`, `FAILED`, `ORPHAN`, `SKIPPED_VERSION_MISMATCH`). Preview documented in `docs/PLUGIN_ARCHITECTURE.md`.
- D2A (upcoming): `IEF_Plugin__mdt.Contract_Version__c` (default `1.0`) + `IEF_PluginContract.SUPPORTED_MAJOR = 1` with loud skip-on-major-mismatch (placeholder + `FRAMEWORK_INTERNAL` event, never throw). See `docs/plugin-contract-versioning.md` (draft).

### Changed

- **DN — IEF naming unification (3a42794):** global rename `IHD_*`→`IEF_*`, `IHD_Plugin__mdt`→`IEF_Plugin__mdt`, LWC `integrationHealthDashboard`→`iefDashboard`, `ihd*`→`ief*`, `lastUpdatedFooter`/`progressBar`/`timeClockPicker`→`ief*`, dirs `force-app/ihd-plugin-*`→`force-app/ief-plugin-*`, package names `IEF_Plugging_*`→`IEF_Plugin_*`, labels/permissions/translations `IHD_*`→`IEF_*`. Clean source-level breaking change (greenfield-only, no migration class); 2GP package renames deferred to next major version. Zero `ihd` outside `docs/archive/**` and `docs/architecture-study/**`.
- **D7 — Core hygiene (e2f801f):** removed `iefTrendIndicator` (+ test) and phantom severity/top-errors fetches, `message.gridSpan` read, `console.log` calls; fixed placeholder label (now binds `plugin.label`); moved 7 `idhIntegration_Evaluation_Rule` CMDT rows calendar → core (C8); unified layout `main/default/lwc`→`lwc/` (C9); extracted shared `lwc/iefPluginContext/iefPluginContext.js` `parseContextData` (C7); typed `IEF_PublishException` + `IEF_PluginType` enum replacing hardcoded strings (C11); documented filter alignment (C3).

### Fixed

- Placeholder cards now show a human-readable label + reason instead of empty/raw key.
- `console.log` removed from production LWC.
- `IntegrationEventPublisher` now throws typed `IEF_PublishException` on publish failure.

## [1.5.1-1] — Dashboard access gate (2026-09-05)

- Core `IntegrationLogsFrameworkv2` @ **1.5.1-1** (`04tak000000fkzlAAA`).
- New graceful access gate: `IntegrationHealthController.getDashboardAccess()` is describe-based, never queries and never throws. Denied users get a friendly `iefAccessDenied` card and exactly one `FRAMEWORK_INTERNAL / DASHBOARD_ACCESS_DENIED` observation instead of dozens of unhandled errors.
- Dashboard now gates first: permission wires became post-gate imperative calls; EMP/LMS connections open only after grant; all fetch paths guard against denial; access-denied callout errors fail silently.

## [1.5.0-1] — Packaging slice (2026-09-05)

- Core `IntegrationLogsFrameworkv2` @ **1.5.0-1** (`04tak000000fjvdAAA`) cut with `--code-coverage`; packaging org tests 100% pass.
- Plugins re-cut against core 1.5.0-1: `IEF_Plugin_TopErrors` @ `0.1.0-1` (`04tak000000fjxFAAQ`), `IEF_Plugin_SeverityDonnut` @ `0.1.0-2` (`04tak000000fjyrAAA`), `IEF_Plugin_Calendar` @ `0.1.0-2` (`04tak000000fk0TAAQ`). The `1.4.2-1` pin from the deferred packaging slice is superseded.
- Clean-room validation: fresh scratch org → core + all 3 plugins installed successfully; dependency chain resolves.
- Versions are **beta** (unpromoted); promote before production installs.
- Core cleanup: dead code removed (−600 lines), action queueable bulkified (≤2 bulk DML per execution, dispatcher chunk cap 50), broken SERVICE plugin configs surfaced as `SERVICE_PLUGIN_SKIPPED` observations, shared `IEF_MetadataUtil` deploy-error formatter, severity map centralized in the selector.
- Agent skill pack vendored at `.opencode/skills/` (`ief-install`, `ief-emit`, `ief-extend`).

## [1.5.0] — Previous core

---

_Older history — see `docs/archive/` and `docs/architecture-study/` (historical, retain `IHD` references intentionally)._
