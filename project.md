# Project Rules: Integration Events Framework

This repository follows **Package-Driven Development (PDD)**. The source of truth is the **Package Version**, not the Org.

## 1. Architectural Boundaries

- **Package Layer**: Contains pure business logic, services, and domain-specific metadata.
  - Must NOT depend on Org-specific metadata (e.g., standard object validation rules, page layouts).
  - Must be deployable to any scratch org without pre-existing configuration.
- **Org Layer**: Contains integrations, triggers, flows, and page layouts.
  - Responsible for "wiring" the package to the standard Salesforce objects.

## 2. Dependency Management

- **No Hard Dependencies**: Packages must not hardcode references to Org classes.
- **Service Locator Pattern**: Use `Type.forName()` to resolve Org implementations of Package interfaces.
  - _See `docs/PDD/04_Implementation_Patterns.md` for the Resolver pattern._

## 3. Testing Strategy (Split Testing)

We use two distinct testing engines. Do not mix them.

| Engine            | Goal                    | Environment    | Scope                                                               |
| :---------------- | :---------------------- | :------------- | :------------------------------------------------------------------ |
| **Package Tests** | Prove Logic Correctness | Scratch Org    | Pure Unit Tests, Mocks, Bulk Safety. NO real SObjects if avoidable. |
| **Org Tests**     | Prove Survivability     | Sandbox / Prod | Integration Tests, Real SObjects, Trigger/Flow behavior.            |

> **CRITICAL RULE**: Package tests (`PKG_*`) are NEVER executed in Sandboxes or Production. They are "Certification Artifacts" only.

## 4. Workflows

- Use `sf package version create` to validate package logic.
- Use `sf package install` to deploy to Sandboxes.
- NEVER use `RunAllTests` in a PDD environment. Use `RunLocalTests` or specific test suites.

## 5. Recent Change — minimal-core-hardening

> Naming is IEF-only after DN. No `IHD`/`ihd`/`Plugging` remains outside `docs/archive/**` and `docs/architecture-study/**`.

- **Phase 1 — D7 hygiene (e2f801f):** dead-code removal (`iefTrendIndicator` deleted, phantom severity/top-errors fetches, `message.gridSpan`, `console.log`), placeholder label fix, shared `c/iefPluginContext.parseContextData` (C7), `main/default/lwc` → `lwc/` (C9), evaluation-rule CMDT rows moved calendar → core (C8), typed `IEF_PublishException` + `IEF_PluginType` enum (C11). Filter alignment (C3) documented on providers.
- **Phase 2 — DN naming unification (3a42794):** global rename `IHD_*`→`IEF_*`, `IHD_Plugin__mdt`→`IEF_Plugin__mdt`, LWC `integrationHealthDashboard`→`iefDashboard` / `ihd*`→`ief*` / `lastUpdatedFooter|progressBar|timeClockPicker`→`ief*`, package dirs `ihd-plugin-*`→`ief-plugin-*` and `IEF_Plugging_*`→`IEF_Plugin_*`. Greenfield-only breaking change (no migration class).

Upcoming on `feature/core-next`: D6 `getCompositionInfo`/`Resolution` introspection and D2A `Contract_Version__c` version guard — see `docs/PLUGIN_ARCHITECTURE.md` preview.
