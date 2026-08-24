# Plugin Architecture — Integration Events Framework

## Overview

The Integration Events Framework uses a **plugin architecture** that enables:

- **Core is agnostic** — doesn't import from plugins, doesn't know about specific cards
- **Plugins extend the framework** — provide cards, triggers, fields, validations, custom code
- **Lightning Message Service (LMS)** — for cross-component communication
- **`lwc:is` dynamic rendering** — plugins register constructors, dashboard renders them

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CORE PACKAGE                                   │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  iefDashboard                                                          │ │
│  │  - Subscribes to IEF_Card_Registry LMS channel                        │ │
│  │  - Discovers plugins via IEF_Plugin__mdt                              │ │
│  │  - Resolves constructors via getConstructor()                         │ │
│  │  - Renders cards via lwc:is={ctor}                                    │ │
│  │  - Passes PluginContext to each card                                   │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  IEF_Card_Registry__c (Lightning Message Channel)                     │ │
│  │  Fields: cardName, cardLabel, action                                  │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  iefDynamicLoader (Single Registry)                                   │ │
│  │  - registerCard(name, ctor) — plugins call this                       │ │
│  │  - getConstructor(name) — dashboard calls this                        │ │
│  │  - getRegisteredNames() — list all registered cards                   │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  iefCardPlaceholder (Fallback UI)                                     │ │
│  │  - Shows when plugin shell is not on page                             │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  IntegrationHealthController (Apex)                                   │ │
│  │  - getActiveCardPlugins() — discovers enabled CARD plugins            │ │
│  │  - getCompositionInfo() — effective composition (upcoming D6)         │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     │ Plugin depends on core
                                     │ (sfdx-project.json dependency)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PLUGIN PACKAGES                                   │
│                                                                              │
│  ┌──────────────────────────────────┐  ┌──────────────────────────────────┐ │
│  │  iefTopErrorsShell               │  │  iefSeverityShell                │ │
│  │  Module-scope:                   │  │  Module-scope:                   │ │
│  │  registerCard("iefTopErrors      │  │  registerCard("iefSeverity       │ │
│  │    CardImpl", ctor)              │  │    CardImpl", ctor)              │ │
│  │                                  │  │                                  │ │
│  │  connectedCallback:              │  │  connectedCallback:              │ │
│  │  publish via LMS                 │  │  publish via LMS                 │ │
│  │  { action: "register" }          │  │  { action: "register" }          │ │
│  │                                  │  │                                  │ │
│  │  [Invisible — renders nothing]   │  │  [Invisible — renders nothing]   │ │
│  └──────────────────────────────────┘  └──────────────────────────────────┘ │
│                                                                              │
│  ┌──────────────────────────────────┐  ┌──────────────────────────────────┐ │
│  │  iefTopErrorsCardImpl            │  │  iefSeverityCardImpl             │ │
│  │  - Receives PluginContext        │  │  - Receives PluginContext        │ │
│  │  - Parses filters from context   │  │  - Parses filters from context   │ │
│  │  - Calls IEF_TopErrorsCardPlugin │  │  - Calls IEF_SeverityCardPlugin  │ │
│  │    .getCardData(filters)         │  │    .getCardData(filters)          │ │
│  │  - Renders iefTopError           │  │  - Renders iefSeverity           │ │
│  │    Integrations visualization    │  │    Breakdown visualization       │ │
│  └──────────────────────────────────┘  └──────────────────────────────────┘ │
│                                                                              │
│  ┌──────────────────────────────────┐  ┌──────────────────────────────────┐ │
│  │  IEF_Plugin__mdt (Metadata)      │  │  Apex Classes                    │ │
│  │  - Self-registration             │  │  - IEF_TopErrorsCardPlugin       │ │
│  │  - PluginType__c = "CARD"        │  │  - IEF_SeverityCardPlugin        │ │
│  │  - LwcComponentName__c = "..."   │  │  - Custom queries                │ │
│  │  - Enabled__c = true             │  │  - Org-specific logic            │ │
│  │  - Contract_Version__c = "1.0"   │  │                                  │ │
│  └──────────────────────────────────┘  └──────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

> **Upcoming in minimal-core-hardening (D6/D2A):** `Contract_Version__c` on `IEF_Plugin__mdt` and the
> `getCompositionInfo()` surface (resolved rows, order, failures + reason) are landing next. The diagram
> already shows their final names so the integrator can finalize without a second doc sweep.

---

## Registration Flow

```
1. Page loads
2. iefDashboard.connectedCallback()
   └─► Subscribe to IEF_Card_Registry LMS channel
   └─► Call fetchActivePlugins() → queries IEF_Plugin__mdt

3. iefTopErrorsShell module loads
   └─► registerCard("iefTopErrorsCardImpl", ctor) executes at MODULE SCOPE

4. iefTopErrorsShell.connectedCallback()
   └─► publish(messageContext, IEF_CARD_REGISTRY, {action: "register"})

5. iefDashboard receives LMS message
   └─► handleCardRegistration() → calls fetchActivePlugins()
   └─► getConstructor("iefTopErrorsCardImpl") → returns ctor

6. Dashboard renders via lwc:is={ctor}
   └─► <lwc:component lwc:is={ctor} context-data={plugin.contextData} />

7. iefTopErrorsCardImpl.connectedCallback()
   └─► Parse contextData (PluginContext) via c/iefPluginContext
   └─► IEF_TopErrorsCardPlugin.getCardData({ filters: context.filters })
   └─► Render iefTopErrorIntegrations visualization
```

---

## PluginContext Contract

When the dashboard renders a card, it passes this context via `contextData`:

```javascript
{
  pluginName: "TopErrors_Card",      // DeveloperName from metadata
  filters: {
    search: "",                      // Free-text search input
    observationType: "",             // Observation type filter value
    integrationCode: "",             // Selected integration code
    correlationId: "",               // Correlation ID filter
    fromOccurredAt: "2026-03-01T00:00:00.000Z",  // Start date (ISO string) or null
    toOccurredAt: "2026-03-26T23:59:59.999Z"     // End date (ISO string) or null
  },
  location: "dashboard",              // Where card is rendered: "dashboard" | "record" | "app"
  refreshToken: "1711395600000",      // Timestamp for cache invalidation
  capabilities: {
    canExport: true,
    canFilter: true,
    canRefresh: true
  }
}
```

**Cards MUST:**

- Parse `contextData` safely via `c/iefPluginContext` (`parseContextData`)
- Use `filters` when fetching data
- Handle loading, error, and empty states
- Treat all filter values as potentially `null` or empty strings

---

## Package Dependencies

```
sfdx-project.json:

┌─────────────────────────────────────┐
│  IntegrationLogsFrameworkv2 (Core)  │
│  └── No dependencies                │
└─────────────────────────────────────┘
            ▲
            │ depends on
            │
┌─────────────────────────────────────┐
│  IEF_Plugin_TopErrors (Plugin)      │
│  └── depends on: Core package       │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  IEF_Plugin_SeverityDonnut          │
│  └── depends on: Core package       │
└─────────────────────────────────────┘
```

---

## Key Components

### 1. `iefDashboard` (Core)

The main dashboard component that:

- Subscribes to `IEF_Card_Registry` LMS channel
- Discovers plugins via `getActiveCardPlugins()` Apex
- Resolves constructors via `getConstructor()` from `iefDynamicLoader`
- Renders cards via `lwc:is={ctor}`
- No fallback to old host — `lwc:is` is the only way

**Key code:**

```javascript
// Subscribe to LMS
this._cardRegistrySubscription = subscribe(
  this.messageContext,
  IEF_CARD_REGISTRY,
  (message) => this.handleCardRegistration(message),
  { scope: APPLICATION_SCOPE }
);

// Resolve constructors
const ctor = getConstructor(plugin.componentName);

// Render via lwc:is
<lwc:component lwc:is={ctor} context-data={plugin.contextData} />;
```

### 2. `iefDynamicLoader` (Core)

The single registry module that:

- Maintains a Map of registered constructors
- Provides `registerCard(name, ctor)` for plugins
- Provides `getConstructor(name)` for dashboard
- No `window.__` globals — uses module-scope Map

**Key code:**

```javascript
const registry = new Map();

export function registerCard(name, constructor) {
  if (registry.has(name)) {
    console.warn(`Duplicate registration for "${name}"`);
    return;
  }
  registry.set(name, constructor);
}

export function getConstructor(name) {
  return registry.get(name) ?? null;
}
```

### 3. `IEF_Card_Registry` (LMS Channel)

Lightning Message Channel for cross-component notification:

- Shells publish `{action: "register"}` when they connect
- Dashboard subscribes and re-resolves plugins
- Works across namespace boundaries

### 4. Shell Components (Plugins)

Each plugin has a shell that:

- Calls `registerCard()` at module scope (deterministic)
- Publishes via LMS on `connectedCallback` (notification)
- Renders nothing — just triggers registration

**Key code:**

```javascript
import { registerCard } from "c/iefDynamicLoader";
import MyCardImpl from "c/myCardImpl";

// Module-scope — executes on import
registerCard("myCardImpl", MyCardImpl);

export default class MyShell extends LightningElement {
  @wire(MessageContext)
  messageContext;

  connectedCallback() {
    publish(this.messageContext, IEF_CARD_REGISTRY, {
      cardName: "myCardImpl",
      cardLabel: "My Card",
      action: "register"
    });
  }
}
```

### 5. Card Implementation Components (Plugins)

Each card:

- Receives `PluginContext` via `contextData` (parsed with `c/iefPluginContext`)
- Parses filters and applies them when fetching data via its own `IEF_*CardPlugin.getCardData(filters)`
- Renders visualization component
- Handles loading, error, empty states

---

## What Plugins Can Extend

| Extension Type       | Description                         | Example                         |
| -------------------- | ----------------------------------- | ------------------------------- |
| **Cards**            | UI components rendered in dashboard | Severity donut, Top errors list |
| **Triggers**         | Automated actions on data changes   | Alert on critical errors        |
| **Fields**           | Custom data model extensions        | Plugin-specific metadata fields |
| **Validations**      | Business rules and constraints      | Required fields, format checks  |
| **Apex Classes**     | Custom logic and services           | Data queries, integrations      |
| **Custom Labels**    | Translatable text                   | UI messages, tooltips           |
| **Metadata Records** | Configuration and registration      | IEF_Plugin\_\_mdt records       |

---

## Upcoming in minimal-core-hardening (preview — integrator to finalize)

> These surfaces are landing in D6 / D2A on `feature/core-next`. Names are final (IEF namespace) so docs don't need a second sweep.

### D6 — Composition introspection

- `IEF_PluginRegistry.resolve(config)` returns `Resolution{instance, status, reason}` instead of a bare instance / silent `null`. Statuses: `ACTIVE`, `ACTIVE_LWC`, `FAILED`, `ORPHAN`, `SKIPPED_VERSION_MISMATCH`.
- `IntegrationHealthController.getCompositionInfo()` (and `CallableIEF` action `getCompositionInfo`) returns `PluginCompositionEntry[]` — `developerName, label, pluginType, apexClassName, lwcComponentName, displayOrder, status, reason, contractVersion` — so admins can see effective order and why a row failed.
- Failures are never cached as `null`; a failed row is recorded with a human-readable `reason` and is re-attemptable next transaction.

### D2A — Contract versioning

- `IEF_Plugin__mdt.Contract_Version__c` (Text, default `1.0`) declares the contract the row was written against. Core exposes `IEF_PluginContract.SUPPORTED_MAJOR = 1`.
- Major mismatch ⇒ row is skipped (no instantiation), placeholder renders with reason, one `FRAMEWORK_INTERNAL` event per row per transaction is emitted and `getCompositionInfo()` reports `SKIPPED_VERSION_MISMATCH`. Minor bumps are additive-only and do not break existing providers.

See `docs/plugin-contract-versioning.md` (drafted in parallel) for evolution rules.

---

## Testing

### Jest Tests

```bash
npm run test:unit
```

All tests pass: **113/113**

### Package Version Creation

```bash
sf package version create --package IntegrationLogsFrameworkv2 --installation-key-bypass --wait 10 --target-dev-hub LWCSB
```

Package version ID: `04tak000000PTV3AAO`

### Installation in Sandbox

```bash
sf package install --package 04tak000000PTV3AAO --target-org cliniDev --wait 10
```

---

## Known Issues & Solutions

| Issue                           | Cause                                            | Solution                              |
| ------------------------------- | ------------------------------------------------ | ------------------------------------- |
| LWC1188 error                   | Missing `lightning__dynamicComponent` capability | Add to meta.xml                       |
| Locker window isolation         | `window.__` doesn't work cross-package           | Use module-scope Map                  |
| FlexiPage template missing      | Empty template field                             | Remove or add valid template          |
| @wire error                     | MessageContext used as getter                    | Use `@wire(MessageContext)` decorator |
| Old plugins show "Unregistered" | Old pattern using legacy host                    | Migrate to new `lwc:is` pattern       |

---

## Next Steps

- [ ] UI improvements in scratch org
- [ ] Additional plugin examples
- [x] Cleanup of deprecated code (legacy host, iefDashboardHost)
- [ ] More comprehensive testing
- [ ] Documentation updates

---

_Architecture documentation — Updated for IEF naming unification (DN) and upcoming D6/D2A surfaces_
