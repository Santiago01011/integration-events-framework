---
name: ief-emit
description: "Trigger: wire IEF emit, integrate events framework domain, add emit points, integration logging adapter, ief connector. Scaffold domain event emission into an org's Apex against the IEF package."
license: Apache-2.0
metadata:
  author: "santiago01011"
  version: "1.0"
---

# IEF Domain Wiring (Emit Points + CMDT)

## Activation Contract

Load when adding integration event emission to a consuming org: an adapter/connector, emit points in business logic, or the CMDT rows (Definition / Evaluation Rule) backing them.

## Hard Rules

- The IEF core is domain-agnostic. NEVER modify the framework package to add a domain — extensibility is always: adapter code + CMDT rows in the consuming org.
- Domain-specific values (`IntegrationCode`, `ObservationType`) must NEVER be hardcoded inside the framework.
- One `idhIntegration_Definition__mdt` row per `IntegrationCode` used in `emit()`. An emit with an unregistered code is invisible to the registry health card.
- One `idhIntegration_Evaluation_Rule__mdt` row per `ObservationType` you want scored. Rule matching is case-insensitive exact match on the observation type. Severity picklist: `INFO, SUCCESS, WARN, ERROR, FATAL`.
- `ObservationType` uses `UPPER_SNAKE_CASE` fact names (e.g. `REVIEW_APPROVED`), never dotted names.
- `emit()` calls must be bulk-safe: pass lists, never call per-row inside a DML/SOQL loop. Emit only on state transitions, not on every field update.
- Use `IntegrationEventPublisher.emit(integrationCode, observationType, correlationId, parentEventId, Map<String,Object> context)` — the canonical 5-arg signature.

## Decision Gates

| Situation                                             | Action                                                                                                                                                                            |
| ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Consuming org has an existing connector/gateway class | Extend it; do not create a parallel emit path                                                                                                                                     |
| No connector exists                                   | Create one thin adapter class (template in `assets/adapter-template.cls`), all business code calls the adapter, adapter is the only file that imports `IntegrationEventPublisher` |
| New fact type has no Evaluation Rule                  | Create the rule row (template in `assets/rule-template.md`) before or with the deploy                                                                                             |
| Need per-fact traceability                            | `correlationId` = business entity Id (order, review, case); chain lifecycle with `parentEventId`                                                                                  |
| High-volume path (order triggers, nightly batches)    | Wrap emits behind an `Enabled__c` check of the Definition row (kill switch) and emit on transitions only                                                                          |

## Execution Steps

1. Inventory the domain: identify state transitions worth logging (dispatch, receive, fail, retry, terminal).
2. Define the taxonomy: one `IntegrationCode` per integration; `UPPER_SNAKE` observation types per fact.
3. Create `idhIntegration_Definition__mdt` and `idhIntegration_Evaluation_Rule__mdt` rows (templates in assets).
4. Create/extend the adapter with typed methods per event (see template); keep `System.debug` fallback behind a framework-present check if the package might be absent.
5. Call the adapter from business code at the identified transitions; pass `correlationId` and `parentEventId`.
6. Add Apex tests: assert adapter produces the right `emit` args (mock or assert persisted `Integration_Log__c` after `Test.stopTest()`). NOTE: platform events CANNOT be SOQL'd in tests (`TestBroker` has no `getDeliveries()`); assert via persisted `Integration_Log__c` records.
7. Deploy, emit a test event, verify the row lands and shows on the dashboard with correct severity.

## Output Contract

Return: taxonomy table (code, observation types, severities, correlation strategy), files created/modified, CMDT rows created, test results, dashboard verification result.

## References

- `assets/adapter-template.cls` — thin adapter with debug fallback
- `assets/rule-template.md` — Evaluation Rule CMDT row
- Live consumer example: `IntegrationEventsConnector.cls` in a consuming-org repo — decoupled gateway pattern with debug fallback and a commented framework hook (see its Option A / Option B structure)
- Framework publisher source: `force-app/integration-logs-framework/main/default/classes/IntegrationEventPublisher.cls` (in the framework repo; if this skill runs in a consumer repo, consult the framework repo clone or the package's published docs)
