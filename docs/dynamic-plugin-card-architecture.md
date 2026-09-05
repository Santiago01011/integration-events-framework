# Dynamic Plugin Card Architecture — Overview

## The Problem

Salesforce DX packages cannot have cross-package static imports. The `c/` namespace prefix only works within the same package.

```
❌ This doesn't work:
   Package A (ief-plugin-toperrors)
   → import { registerCard } from "c/iefDynamicLoader"  // iefDynamicLoader is in Package B

   Locker Service also prevents: window.__sharedVar = value
   → Each package gets its own sandboxed window object
```

**Goal**: Enable the core package to render plugin LWC components without static imports.

---

## The Solution: Shell + Loader Pattern with Custom Events

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LIGHTNING PAGE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────┐  ┌─────────────────────┐  ┌─────────────────┐ │
│  │  iefDashboardHost       │  │  iefTopErrorsShell  │  │ iefSeverityShell│ │
│  │  (Core Package)         │  │  (Plugin Package)   │  │ (Plugin Package)│ │
│  │                         │  │                     │  │                 │ │
│  │  1. Query IEF_Plugin__mdt│  │  connectedCallback:│  │ connectedCallback│
│  │  2. Listen for events   │  │  dispatch event with│  │ dispatch event  │ │
│  │  3. Render via lwc:is   │  │  iefTopErrorsCardImpl│ │ with iefSeverity│ │
│  │     ┌─────────────────┐ │  │  constructor       │  │ CardImpl const. │ │
│  │     │ CustomEvent     │ │  └─────────┬───────────┘  └────────┬────────┘ │
│  │     │ "iefregistercard"│ │            │                      │          │
│  │     │ bubbles: true    │ │            │                      │          │
│  │     │ composed: true   │ │            └──────────┬───────────┘          │
│  │     └─────────────────┘ │                       │                       │
│  │            │            │                       ▼                       │
│  │            │◄───────────┴──────────────────────┘                        │
│  │            ▼                                                            │
│  │  Local cardRegistry Map                                                 │
│  │  "iefTopErrorsCardImpl" → [Constructor]                                 │
│  │  "iefSeverityCardImpl"  → [Constructor]                                 │
│  │            │                                                            │
│  │            ▼                                                            │
│  │  lwc:is={ctor} → renders iefTopErrorsCardImpl or iefSeverityCardImpl   │
│  └─────────────────────────┘                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Package Structure

```
integration-events-framework/
│
├── force-app/integration-logs-framework/    # CORE PACKAGE
│   ├── main/default/lwc/
│   │   ├── iefDashboardHost/               # NEW - Main dashboard
│   │   │   ├── iefDashboardHost.js         # Queries plugins, listens for events, renders lwc:is
│   │   │   ├── iefDashboardHost.html       # Template with lwc:is={entry.ctor}
│   │   │   └── iefDashboardHost.js-meta.xml
│   │   ├── iefDynamicLoader/               # NEW - JS module (currently unused after Event refactor)
│   │   │   └── iefDynamicLoader.js
│   │   ├── iefCardPlaceholder/             # NEW - Fallback UI
│   │   └── ...existing components...
│   └── classes/
│       └── IntegrationHealthController.cls # Has getActiveCardPlugins(), getSeverityCounts(), etc.
│
├── force-app/ief-plugin-toperrors/         # TOPERRORS PLUGIN PACKAGE
│   ├── main/default/lwc/
│   │   ├── iefTopErrorsShell/              # NEW - Registration shell
│   │   │   └── iefTopErrorsShell.js        # Dispatches CustomEvent on connectedCallback
│   │   └── iefTopErrorsCardImpl/           # NEW - Card implementation
│   │       ├── iefTopErrorsCardImpl.js     # Fetches data, renders iefTopErrorIntegrations
│   │       └── iefTopErrorsCardImpl.html
│   └── lwc/
│       └── iefTopErrorIntegrations/        # EXISTING - Visualization component
│           └── iefTopErrorIntegrations.js  # Ranked list with trend indicators
│
└── force-app/ief-plugin-severity/          # SEVERITY PLUGIN PACKAGE
    ├── main/default/lwc/
    │   ├── iefSeverityShell/               # NEW - Registration shell
    │   │   └── iefSeverityShell.js         # Dispatches CustomEvent on connectedCallback
    │   └── iefSeverityCardImpl/            # NEW - Card implementation
    │       ├── iefSeverityCardImpl.js      # Fetches data, renders iefSeverityBreakdown
    │       └── iefSeverityCardImpl.html
    └── lwc/
        └── iefSeverityBreakdown/           # EXISTING - Visualization component
            └── iefSeverityBreakdown.js     # Donut chart with conic-gradient
```

---

## Key Components

### 1. iefDashboardHost (Core Package)

**Role**: Main dashboard that renders plugin cards dynamically.

**How it works**:

```javascript
// 1. Queries IEF_Plugin__mdt for CARD plugins
const plugins = await getActiveCardPlugins();

// 2. For each plugin, checks local cardRegistry
const ctor = getConstructor(plugin.componentName); // "iefTopErrorsCardImpl"

// 3. If constructor found, renders via lwc:is
// If not found, renders iefCardPlaceholder

// 4. Listens for registration events from shells
window.addEventListener("iefregistercard", this.handleRegistration);
```

**Key insight**: The dashboard maintains a LOCAL `cardRegistry` Map that gets populated by Custom Events from shells.

### 2. iefTopErrorsShell / iefSeverityShell (Plugin Packages)

**Role**: Invisible registration components that "claim" a page for a plugin.

**How it works**:

```javascript
connectedCallback() {
  const event = new CustomEvent("iefregistercard", {
    bubbles: true,    // Bubbles up to document
    composed: true,   // Crosses shadow DOM and Locker Service boundaries
    detail: {
      name: "iefTopErrorsCardImpl",
      constructor: IefTopErrorsCardImpl  // Imported from same package
    }
  });
  this.dispatchEvent(event);
}
```

**Key insight**: `composed: true` is what allows the event to cross Locker Service namespace boundaries.

### 3. iefTopErrorsCardImpl / iefSeverityCardImpl (Plugin Packages)

**Role**: Card implementations that fetch data and render visualizations.

**How it works**:

```javascript
// 1. Receives contextData as JSON string from dashboard
@api contextData;

// 2. Fetches its own data via Apex
const result = await getTopErrorIntegrations({ topN: 5 });

// 3. Passes data to existing visualization component
<c-ief-top-error-integrations integrations={integrations}></c-ief-top-error-integrations>
```

**Key insight**: Cards are self-sufficient — they fetch their own data rather than receiving it from the dashboard.

---

## Key Decisions & Why

| Decision                                    | Alternative                 | Why                                                                                                   |
| ------------------------------------------- | --------------------------- | ----------------------------------------------------------------------------------------------------- |
| **Custom Events**                           | Global window registry      | Locker Service isolates window objects per namespace. Events with `composed: true` cross boundaries.  |
| **Shells are separate from impls**          | Single component per plugin | Separates concerns: shells handle registration, impls handle rendering. Shells can be tiny/invisible. |
| **Cards fetch own data**                    | Dashboard passes data       | Each card knows what data it needs. Dashboard stays simple.                                           |
| **JSON for cross-package @api**             | Complex objects             | JSON is the only reliable way to pass data across package boundaries in LWC.                          |
| **Reuse existing visualization components** | Create new ones             | iefSeverityBreakdown and iefTopErrorIntegrations already exist and work. Why rewrite?                 |
| **apiVersion 65.0**                         | 62.0 (spec)                 | `lwc:is` requires apiVersion 63+. 65.0 is current stable.                                             |

---

## What Was Learned During Implementation

### Critical Discovery: Locker Service Window Isolation

**First attempt**: Use `window.__iefCardRegistry` as a global registry.
**Result**: FAILED — Each package gets its own sandboxed window.

```javascript
// In ief-toperrors package:
window.__iefCardRegistry.set("iefTopErrorsCardImpl", ctor); // Works

// In integration-logs-framework package:
window.__iefCardRegistry.get("iefTopErrorsCardImpl"); // Returns undefined!
// Different window object!
```

**Solution**: Custom Events with `composed: true`.

### Critical Discovery: Metadata Field Names

**Original spec used**: `Type__c`, `Is_Enabled__c`, `LWC_Name__c`, `Order__c`
**Actual fields**: `PluginType__c`, `Enabled__c`, `LwcComponentName__c`, `DisplayOrder__c`

**Lesson**: Always check the actual custom metadata type definition in the org.

### Critical Discovery: Enabled\_\_c Default Value

**Problem**: New metadata records had `Enabled__c=false` by default.
**Result**: `getActiveCardPlugins()` only returns enabled records, so new plugins were invisible.

**Solution**: Set `Enabled__c=true` in metadata files.

---

## Current Limitations

| Limitation                                         | Impact                                  | Improvement Path                                              |
| -------------------------------------------------- | --------------------------------------- | ------------------------------------------------------------- |
| No Jest tests for event-based registration         | Tests fail with new pattern             | Update mocks for CustomEvent                                  |
| Dashboard reloads all plugins on each registration | Performance if many plugins             | Batch registrations, reload once                              |
| No retry logic for failed data fetches             | Transient errors show error state       | Add exponential backoff                                       |
| No plugin ordering guarantee                       | Cards may render in unpredictable order | Already handled via `order` field                             |
| Shell must be on page to register                  | User must add shell in App Builder      | Consider auto-registration via custom label or org preference |

---

## Data Flow Sequence

```
1. Page loads
2. iefDashboardHost.connectedCallback() fires
3.   └─► getActiveCardPlugins() queries IEF_Plugin__mdt
4.   └─► Returns: [{name: "TopErrors Card", componentName: "iefTopErrorsCardImpl", ...}, ...]
5. iefTopErrorsShell.connectedCallback() fires
6.   └─► Dispatches CustomEvent("iefregistercard", {name: "iefTopErrorsCardImpl", ctor})
7. iefDashboardHost.handleRegistration() fires
8.   └─► cardRegistry.set("iefTopErrorsCardImpl", ctor)
9.   └─► loadPlugins() called again
10.  └─► getConstructor("iefTopErrorsCardImpl") returns ctor
11.  └─► Renders <lwc:component lwc:is={ctor} />
12. iefTopErrorsCardImpl.connectedCallback() fires
13.  └─► getTopErrorIntegrations() fetches data
14.  └─► Passes to <c-ief-top-error-integrations integrations={data} />
15. iefTopErrorIntegrations renders ranked list with bars and trends
```

---

## Areas for Discussion: What to Improve?

### 1. Performance

- **Current**: Dashboard reloads plugins on every registration event
- **Idea**: Batch events, reload once after all shells have registered
- **Tradeoff**: Complexity vs perceived load time

### 2. Maintainability

- **Current**: Each plugin needs 3 LWCs (shell, card impl, visualization)
- **Idea**: Create a base class or mixin for common card logic
- **Tradeoff**: Abstraction vs simplicity

### 3. Developer Experience

- **Current**: Plugin dev must create shell, card impl, metadata record
- **Idea**: CLI command or template generator for new plugins
- **Tradeoff**: Tooling overhead vs developer productivity

### 4. Testing

- **Current**: Jest tests fail because they expect old module-scope pattern
- **Idea**: Mock CustomEvent in tests, verify registration flow
- **Tradeoff**: Test complexity vs confidence

### 5. Documentation

- **Current**: No guide for plugin developers
- **Idea**: Create `PLUGIN_DEVELOPMENT.md` with step-by-step guide
- **Tradeoff**: Documentation maintenance vs onboarding time

### 6. Migration

- **Current**: Old and new plugins coexist (4 cards shown)
- **Idea**: Deprecation path for old IEF_Plugin Apex pattern
- **Tradeoff**: Backward compatibility vs cleaner architecture

---

## Next Steps

1. **Review this document** — Understand the architecture
2. **Identify priorities** — What's most important to improve?
3. **Create new SDD change** — `/sdd-new ief-plugin-refinement` or similar
4. **Discuss and decide** — Which improvements to tackle first

---

_Generated after implementing the Dynamic Plugin Card Architecture (PR #34)_
