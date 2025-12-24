# Integration Events Framework

An observability kernel for Salesforce integrations. This framework decouples **what happened** (Observation) from **what it means** (Interpretation).

## Core Philosophy

1.  **Emit, Don't Judge**: The code emitting events shouldn't decide if it's a "Success" or "Failure". It just reports "HTTP 200" or "Exception Thrown".
2.  **Context is King**: All details (payloads, stack traces, headers) go into a JSON `Context` field. We don't create new fields for every new requirement.
3.  **Metadata Driven**: The UI decides how to color-code an event based on Custom Metadata, not hardcoded Apex logic.

---

## Data Model Map

### 1. The Transport: `IntegrationEvent__e`
The Platform Event that carries the signal.
*   `IntegrationCode__c`: Unique identifier for the integration flow (e.g., `SAP_ORDER_SYNC`).
*   `ObservationType__c`: What just happened? (e.g., `HTTP_REQUEST`, `HTTP_RESPONSE`, `APEX_EXCEPTION`).
*   `CorrelationId__c`: A unique ID linking all events in a single transaction.
*   `ParentEventId__c`: (Optional) ID of the event that triggered this one, for chaining.
*   `Context__c`: A JSON string containing all relevant data (payloads, error messages, IDs).
*   `OccurredAt__c`: Timestamp.

### 2. The Storage: `Integration_Log__c`
The persistent object where events are stored for history.
*   Mirrors `IntegrationEvent__e` fields exactly.
*   `Normalized_Context__c`: A high-level category (e.g., "Orders") extracted from the context for reporting and filtering.

### 3. The Registry: `idhIntegration_Definition__mdt`
Defines which integrations exist in this Org.
*   `IntegrationCode__c`: Matches the code sent in the event.
*   `Enabled__c`: Master switch to ignore/process events for this flow.
*   `Direction__c`: `Inbound` or `Outbound`.

### 4. The Normalizer: `Integration_Context_Mapping__mdt`
Maps raw context keywords to high-level categories.
*   `Context_Keyword__c`: A string to look for in the context (e.g., "OrderCreation").
*   `Normalized_Context__c`: The category to assign (e.g., "Orders").

### 5. The Dictionary: `idhIntegration_Evaluation_Rule__mdt`
Defines how to interpret an `ObservationType` in the UI.
*   `ObservationType__c`: Matches the type sent in the event.
*   `Severity__c`: Controls the color in the dashboard (`Info`=Blue, `Success`=Green, `Warning`=Yellow, `Error`=Red).

---

## Developer Guide

### How to Emit an Event

You don't have to create `Integration_Log__c` records directly. Use the `IntegrationEventPublisher` class.

```apex
// 1. Define your context (any Map or Object)
Map<String, Object> context = new Map<String, Object>{
    'url' => 'https://api.example.com/orders',
    'method' => 'POST',
    'body' => '...'
};

// 2. Emit the event
IntegrationEventPublisher.emit(
    'SAP_ORDER_SYNC',       // Integration Code
    'HTTP_REQUEST',         // Observation Type
    '12345-abcde',          // Correlation ID
    null,                   // Parent Event ID (Optional)
    context                 // Context Data (will be serialized to JSON)
);
```

### Best Practices
*   **Correlation IDs**: Always generate a Correlation ID at the start of a transaction and pass it through every step.
*   **No "Status" Fields**: Don't try to calculate "Status=Failed" in your Apex code. Just emit `HTTP_500` or `CATCH_BLOCK`. Let the Admin configure that `HTTP_500` shows as Red.

---

## Sys Admin Guide (UI & Configuration)

### 1. Registering a New Integration
When developers add a new integration (e.g., "Workday Employee Sync"), you need to register it so it appears in filters.

1.  Go to **Setup** > **Custom Metadata Types**.
2.  Manage Records for **Integration Definition**.
3.  Create a new record:
    *   **Integration Code**: `WORKDAY_SYNC` (Must match what developers used).
    *   **Label**: Workday Employee Sync.
    *   **Enabled**: Checked.

### 2. Configuring Dashboard Colors (Interpretation)
You decide what is an "Error". If `HTTP_404` is normal for your flow, you can make it Green or Yellow.

1.  Go to **Setup** > **Custom Metadata Types**.
2.  Manage Records for **Integration Evaluation Rule**.
3.  Create/Edit a record:
    *   **Observation Type**: `HTTP_404`.
    *   **Severity**: `Warning` (Yellow) or `Info` (Blue).
    *   *Note: If you set it to `Error`, it will show as Red in the dashboard.*

### 3. Monitoring
Access the **Integration Health Dashboard** tab.
*   **Timeline**: See events flow in real-time.
*   **Filters**: Filter by Integration Code or Correlation ID.
*   **Drill-down**: Click any event to see the full JSON Context.
