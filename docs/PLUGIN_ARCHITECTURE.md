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
│  │  integrationHealthDashboard                                            │ │
│  │  - Subscribes to IEF_Card_Registry LMS channel                        │ │
│  │  - Discovers plugins via IHD_Plugin__mdt                              │ │
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
│  │  - getSeverityCounts() — data for severity card                       │ │
│  │  - getTopErrorIntegrations() — data for top errors card               │ │
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
│  │  - Calls getTopErrorIntegrations │  │  - Calls getSeverityCounts       │ │
│  │  - Renders ihdTopError           │  │  - Renders ihdSeverity           │ │
│  │    Integrations visualization    │  │    Breakdown visualization       │ │
│  └──────────────────────────────────┘  └──────────────────────────────────┘ │
│                                                                              │
│  ┌──────────────────────────────────┐  ┌──────────────────────────────────┐ │
│  │  IHD_Plugin__mdt (Metadata)      │  │  Apex Classes                    │ │
│  │  - Self-registration             │  │  - IHD_TopErrorsPlugin           │ │
│  │  - PluginType__c = "CARD"        │  │  - IHD_SeverityBreakdownPlugin   │ │
│  │  - LwcComponentName__c = "..."   │  │  - Custom queries                │ │
│  │  - Enabled__c = true             │  │  - Org-specific logic            │ │
│  └──────────────────────────────────┘  └──────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Registration Flow

```
1. Page loads
2. integrationHealthDashboard.connectedCallback()
   └─► Subscribe to IEF_Card_Registry LMS channel
   └─► Call fetchActivePlugins() → queries IHD_Plugin__mdt

3. iefTopErrorsShell module loads
   └─► registerCard("iefTopErrorsCardImpl", ctor) executes at MODULE SCOPE

4. iefTopErrorsShell.connectedCallback()
   └─► publish(messageContext, IEF_CARD_REGISTRY, {action: "register"})

5. integrationHealthDashboard receives LMS message
   └─► handleCardRegistration() → calls fetchActivePlugins()
   └─► getConstructor("iefTopErrorsCardImpl") → returns ctor

6. Dashboard renders via lwc:is={ctor}
   └─► <lwc:component lwc:is={ctor} context-data={plugin.contextData} />

7. iefTopErrorsCardImpl.connectedCallback()
   └─► Parse contextData (PluginContext)
   └─► getTopErrorIntegrations({ filters: context.filters })
   └─► Render ihdTopErrorIntegrations visualization
```

---

## PluginContext Contract

When dashboard renders a card, it passes this context via `contextData`:

```javascript
{
  pluginName: "TopErrors_Card",      // DeveloperName from metadata
  filters: {
    startDate: "2026-03-01",
    endDate: "2026-03-25",
    severity: ["ERROR", "FATAL"],
    integrationCode: null
  },
  location: "dashboard",             // or "record", "app"
  refreshToken: "1711395600000",      // Timestamp for cache invalidation
  capabilities: {
    canExport: true,
    canFilter: true,
    canRefresh: true
  }
}
```

**Cards MUST:**

- Parse `contextData` safely with try-catch
- Use `filters` when fetching data
- Handle loading, error, and empty states

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
│  IEF_Plugging_TopErrors (Plugin)    │
│  └── depends on: Core package       │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  IEF_Plugging_SeverityDonnut        │
│  └── depends on: Core package       │
└─────────────────────────────────────┘
```

---

## Key Components

### 1. `integrationHealthDashboard` (Core)

The main dashboard component that:

- Subscribes to `IEF_Card_Registry` LMS channel
- Discovers plugins via `getActiveCardPlugins()` Apex
- Resolves constructors via `getConstructor()` from `iefDynamicLoader`
- Renders cards via `lwc:is={ctor}`
- No fallback to old `ihdPluginHost` — `lwc:is` is the only way

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

- Receives `PluginContext` via `contextData`
- Parses filters and applies them when fetching data
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
| **Metadata Records** | Configuration and registration      | IHD_Plugin\_\_mdt records       |

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
| Old plugins show "Unregistered" | Old pattern using `ihdPluginHost`                | Migrate to new `lwc:is` pattern       |

---

## Next Steps

- [ ] UI improvements in scratch org
- [ ] Additional plugin examples
- [ ] Cleanup of deprecated code (ihdPluginHost)
- [ ] More comprehensive testing
- [ ] Documentation updates

---

_Architecture documentation — Updated after Lightning Message Service integration_
