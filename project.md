# Project Rules: Integration Events Framework

This repository follows **Package-Driven Development (PDD)**. The source of truth is the **Package Version**, not the Org.

## 1. Architectural Boundaries

- **Core Package**: Contains the dashboard, plugin host, interfaces, registry, and services.
  - `force-app/integration-logs-framework/`
  - No dependencies on other packages.
  - Must be deployable to any scratch org without pre-existing configuration.
- **Plugin Packages**: Extend the core with cards, visualizations, and custom logic.
  - `force-app/ihd-plugin-calendar/`
  - `force-app/ihd-plugin-severity/`
  - `force-app/ihd-plugin-toperrors/`
  - Each depends on the core package.
- **Org Layer**: Contains integrations, triggers, flows, and page layouts.
  - Responsible for "wiring" the package to the standard Salesforce objects.

## 2. Dependency Management

- **No Hard Dependencies**: Packages must not hardcode references to Org classes.
- **Service Locator Pattern**: Use `Type.forName()` to resolve Org implementations of Package interfaces.
  - _See `docs/PDD/04_Implementation_Patterns.md` for the Resolver pattern._
- **Plugin Dependencies**: Plugin packages declare dependency on core via `sfdx-project.json`.

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

## 5. Plugin Architecture

- Plugins register via module-scope `registerCard()` in `iefDynamicLoader`.
- Core dashboard discovers plugins via `IHD_Plugin__mdt` metadata.
- Filter context propagates to plugins via `PluginContext` JSON.
- Plugins communicate via `IEF_Plugin_Actions__c` LMS channel.

📖 **[Plugin Architecture Documentation](docs/PLUGIN_ARCHITECTURE.md)**
