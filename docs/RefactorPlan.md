# 🔧 Integration Logs Framework — Extraction & Generalization Plan

## 🎯 Objective

Transform a **project-specific integration logging utility** into a **semantically neutral, org-agnostic integration observability framework**, without breaking existing consumers.

The framework must:

* observe events, not interpret them
* be configurable via metadata
* support multiple integrations per org
* avoid SAP-specific or domain-specific assumptions

---

## PHASE 0 — Safety Net (MANDATORY)

### 0.1 Snapshot current behavior

* Identify all current emit points
* Capture:

  * statuses written
  * fields populated
  * assumptions made by UI/reports

### 0.2 Freeze external API

* Do **not** change:

  * public Apex method signatures
  * object API names
* Add new APIs if needed, but don’t break existing ones

---

## PHASE 1 — Semantic Decoupling (CORE)

### 1.1 Replace “Status” with “Observation Type”

#### Action:

* Introduce a neutral field (or metadata mapping):

  * `ObservationType__c`
* Allowed values must represent **facts only**

Examples:

* `REQUEST_DISPATCHED`
* `RESPONSE_RECEIVED`
* `HTTP_ERROR`
* `EXCEPTION_THROWN`
* `TIMEOUT`
* `PAYLOAD_REJECTED`

❌ Forbidden:

* `SUCCESS`
* `FAILED`
* `RETRY`
* `CRITICAL`

---

### 1.2 Externalize interpretation rules

#### Action:

* Create Custom Metadata Type:

  * `Integration_Evaluation_Rule__mdt`

Fields:

* `ObservationType__c`
* `Severity__c`
* `Retryable__c`
* `Terminal__c`

#### Rule:

* Framework **never evaluates**
* Consumers decide how to interpret events

---

## PHASE 2 — Integration Definition Abstraction

### 2.1 Create Integration Definition metadata

#### New Custom Metadata:

`Integration_Definition__mdt`

Fields:

* `IntegrationCode__c`
* `Direction__c` (Inbound / Outbound)
* `Transport__c` (HTTP, Event, File, etc.)
* `CorrelationStrategy__c`
* `Enabled__c`

#### Framework behavior:

* All events reference `IntegrationCode`
* No branching logic on system names

---

### 2.2 Remove project-specific identifiers

#### Action:

* Replace:

  * hardcoded system names
  * object-specific logic
* With:

  * metadata lookups
  * injected configuration

---

## PHASE 3 — Correlation Model (FOUNDATIONAL)

### 3.1 Introduce explicit correlation

#### Required fields:

* `CorrelationId__c`
* `ParentEventId__c`

#### Rules:

* CorrelationId must survive:

  * async boundaries
  * retries
  * batch executions

Framework responsibility:

* propagate correlation
* never generate business meaning

---

## PHASE 4 — Public Apex API Hardening

### 4.1 Define minimal emitter contract

Create (or refactor to):

```java
IntegrationEventEmitter.emit(
    String integrationCode,
    String observationType,
    String correlationId,
    Map<String, Object> context
);
```

Rules:

* No SAP terms
* No protocol-specific logic
* No retries inside emitter

---

## PHASE 5 — UI Re-scope

### 5.1 Make UI diagnostic-only

#### UI must:

* show timelines
* group by correlation
* filter by integrationCode

#### UI must NOT:

* decide success/failure
* trigger retries
* encode business meaning

---

## PHASE 6 — Backward Compatibility Layer

### 6.1 Legacy adapter

Create a mapping layer:

* Old `Status__c` → new `ObservationType__c`
* Existing dashboards keep working

Mark legacy fields:

* `@deprecated`
* documented for future removal

---

## PHASE 7 — Documentation & Packaging

### 7.1 README rewrite (mandatory)

Include:

* What the framework observes
* What it explicitly does NOT decide
* How to define integrations via metadata
* Example: SAP, REST, Event-based integration

### 7.2 Package hygiene

* Remove org-specific defaults
* Provide sample metadata only
* Ensure clean install in empty org

---

## PHASE 8 — Validation Criteria

The refactor is successful if:

* A completely unrelated system (e.g. FTP, MQ, Event) can emit logs
* No Apex code change is required per integration
* Status semantics live entirely in metadata
* SAP is nowhere in core logic
