# Integration Health Dashboard - Architecture

This document provides a detailed architectural overview of the Integration Health Dashboard (IHD) framework.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            SALESFORCE ORG                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────────────┐  │
│  │   APEX CODE     │      │ Platform Event  │      │   Integration_Log__c    │  │
│  │   (Your Flows)  │─────>│ IntegrationEvent│─────>│   (Persistent Store)    │  │
│  │                 │ emit │      __e        │trigger│                         │  │
│  └─────────────────┘      └─────────────────┘      └───────────┬─────────────┘  │
│                                   │                            │                │
│                                   │ EMP API                    │ SOQL           │
│                                   ▼                            ▼                │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                     integrationHealthDashboard (LWC)                     │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────────────┐  │   │
│  │  │ ihdFilters │  │  ihdTable  │  │ihdStatsCard│  │ihdIntegrationSumm..│  │   │
│  │  └────────────┘  └────────────┘  └────────────┘  └────────────────────┘  │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐                          │   │
│  │  │ihdDetail.. │  │ihdAdminPan.│  │utilsLogsApi│                          │   │
│  │  └────────────┘  └────────────┘  └────────────┘                          │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                    CUSTOM METADATA (Configuration)                        │  │
│  │  ┌─────────────────────────────┐  ┌─────────────────────────────────────┐ │  │
│  │  │ idhIntegration_Definition   │  │ idhIntegration_Evaluation_Rule     │ │  │
│  │  │ (Registry, Kill Switch)     │  │ (Severity Mapping)                 │ │  │
│  │  └─────────────────────────────┘  └─────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Layer Responsibilities

### 1. Emission Layer (`IntegrationEventPublisher`)

The public API for developers. Responsibilities:

- Accept raw telemetry data from any integration flow.
- Validate against the Kill Switch (disabled integrations are blocked).
- Truncate fields to platform limits.
- Publish Platform Events asynchronously.
- Surface publishing failures by throwing an exception so calling transactions can react.

**Key Methods:**

- `emit(code, type, correlationId, parentId, context)` - Main entry point.
- `emit(code, type, correlationId, parentId, contextMap)` - Overload for Map contexts.
- `handleControllerError(Exception e)` - Standardized UI error handler.

### 2. Transport Layer (`IntegrationEvent__e`)

A Platform Event that serves as a real-time signal carrier.

**Fields:**
| Field | Type | Purpose |
| ------------------- | -------- | -------------------------------- |
| `IntegrationCode__c`| Text | Unique identifier for the flow |
| `ObservationType__c`| Text | The raw observation (e.g., HTTP_200) |
| `CorrelationId__c` | Text | Traceability across systems |
| `ParentEventId__c` | Text | Event chaining |
| `Context__c` | LongText | JSON payload with details |
| `OccurredAt__c` | DateTime | When the event happened |

### 3. Persistence Layer (`IntegrationLogHandler` → `Integration_Log__c`)

Triggered by Platform Events to create permanent records.

**Key Behavior:**

- Runs `without sharing` to ensure logs are always created.
- Normalizes context via `IntegrationContextService`.
- Inserts records `as system` to bypass sharing rules.

### 4. Service Layer (`IntegrationHealthService`)

Business logic for the dashboard. Responsibilities:

- Aggregate logs into integration summaries.
- Apply metadata-driven severity rules.
- Handle administrative operations (delete, update).

### 5. Selector Layer (`IntegrationHealthSelector`)

Data access layer with FLS enforcement.

**Key Methods:**

- `queryLogs(...)` - Keyset pagination with dynamic filtering.
- `getIntegrationDefinitions()` - Fetches registry metadata.
- `getEvaluationRules(type)` - Fetches severity for a given observation type.
- `isAdminUser()` - Checks for `Integration_Dashboard_Admin` permission set.

### 6. Controller Layer (`IntegrationHealthController`)

Thin Aura-enabled controller that delegates to services.

**Error Handling Pattern:**
All methods use `IntegrationEventPublisher.handleControllerError(e)` to:

1. Log the error to the framework itself (`FRAMEWORK_INTERNAL`).
2. Re-throw as `AuraHandledException` for UI display.

### 7. UI Layer (LWC Components)

| Component                    | Responsibility                                   |
| ---------------------------- | ------------------------------------------------ |
| `integrationHealthDashboard` | Main container, state management, tab navigation |
| `ihdFilters`                 | User input for search, date, type filters        |
| `ihdTable`                   | Paginated data table with row actions            |
| `ihdDetailDrawer`            | Modal for viewing log details (view-only)        |
| `ihdStatsCard`               | Reusable card for metrics display                |
| `ihdIntegrationSummaryCard`  | Summary tile for integration health              |
| `ihdAdminPanel`              | Admin interface for registry management          |
| `utilsLogsApi`               | Shared state, caching, EMP subscription, toasts  |

---

## Metadata Configuration

### Integration Definition (`idhIntegration_Definition__mdt`)

Controls the identity and behavior of integrations.

| Field                | Purpose                                |
| -------------------- | -------------------------------------- |
| `IntegrationCode__c` | Exact match to code used in Apex       |
| `Label__c`           | Display name for UI                    |
| `Group__c`           | Logical grouping for summaries         |
| `Direction__c`       | Inbound / Outbound / Bidirectional     |
| `Transport__c`       | Data source (SAP, MongoDB, REST, etc.) |
| `Enabled__c`         | Kill switch - false blocks emission    |

### Evaluation Rule (`idhIntegration_Evaluation_Rule__mdt`)

Maps raw observations to business severity.

| Field                | Purpose                                   |
| -------------------- | ----------------------------------------- |
| `ObservationType__c` | The raw string emitted (e.g., `HTTP_500`) |
| `Severity__c`        | SUCCESS, INFO, WARNING, ERROR, FATAL      |

---

## Real-Time Subscription (EMP API)

The `utilsLogsApi` module manages real-time updates:

1. **Channel Resolution:** Calls `getEventChannel()` to get `/event/IntegrationEvent__e`.
2. **Subscription:** Uses `subscribe()` from `lightning/empApi`.
3. **Reconnection:** Automatically retries on session expiration (max 3 attempts).
4. **Component Cleanup:** Tracks subscriptions per component for proper `disconnectedCallback()` cleanup.

---

## Security Model

### Permission Sets

| Permission Set                | Access Level                               |
| ----------------------------- | ------------------------------------------ |
| `Integration_Dashboard_Read`  | View logs and summaries                    |
| `Integration_Dashboard_Admin` | View + Register integrations + Manage logs |

### FLS Enforcement

- All SOQL queries in `IntegrationHealthSelector` use `AccessLevel.USER_MODE`.
- Field-level access is checked dynamically via `fieldExists()`.

### Sharing Rules

- `IntegrationLogHandler` uses `without sharing` to ensure log creation.
- `IntegrationEventPublisher` uses `without sharing` for kill switch checks.
- All other classes use `with sharing` for query-time security.

### Error Propagation

- `IntegrationEventPublisher.emit(...)` throws if `EventBus.publish` fails, so upstream callers should be prepared to handle a publish failure in their transaction.

---

## Extension Points

### Adding New Observation Types

1. Emit the new type in Apex: `IntegrationEventPublisher.emit('MY_CODE', 'NEW_TYPE', ...)`.
2. Create an `idhIntegration_Evaluation_Rule__mdt` record with `ObservationType__c = 'NEW_TYPE'`.
3. The dashboard will automatically apply the new severity.

### Adding New Integrations

1. Start emitting events with a new `IntegrationCode`.
2. The integration will appear as "Unregistered" in the Admin Panel.
3. Click "Register / Update" to add label, group, transport, and direction.

### Custom Dashboard Embedding

The `integrationHealthDashboard` component can be added to:

- App Builder pages
- Record pages (e.g., Account-specific integrations)
- Community pages (with appropriate permission sets)
