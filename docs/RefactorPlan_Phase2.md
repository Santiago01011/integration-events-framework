# Integration Events Framework — Refactor Plan (Phase 2)

> *“I don’t need to keep any backward compatibility, treat it as a new project”

---

## What this decision unlocks (important)

Dropping backward compatibility allows you to:

* delete legacy fields and concepts completely
* remove semantic adapters and mapping layers
* redesign Platform Events cleanly
* enforce namespace-safe patterns everywhere
* define a **tight, minimal public contract**

In other words: **this becomes a real framework, not a refactor**.

---

## New starting point (reset the mental model)

Treat this as:

> **“An integration observability kernel for Salesforce orgs”**

Not:

* SAP-related
* HTTP-related
* success/failure-oriented

Just *observation + correlation + transport*.

---

## Clean, agent-ready plan (v2 – no legacy)

### PHASE 1 — Kill legacy concepts (first task)

Tell the agent to **delete**, not adapt:

* ❌ `Status__c`
* ❌ any `Success`, `Failed`, `Retry` enums
* ❌ project-specific naming
* ❌ assumptions about protocols

If a concept answers *“what does this mean?”* → it does **not** belong in core.

---

### PHASE 2 — Define the canonical event model (non-negotiable)

#### Platform Event = pure observation

Fields (minimum, no more):

* `IntegrationCode__c`
* `ObservationType__c`
* `CorrelationId__c`
* `ParentEventId__c` (nullable)
* `OccurredAt__c`
* `Context__c` (opaque, JSON/string)

Rules:

* No booleans
* No severity
* No retry flags
* No system names

This is now your **contract**.

---

### PHASE 3 — Namespace correctness (do it now, not later)

Since this is a new project, enforce this strictly.

#### Apex

* Never expose raw API names
* Resolve PE names via `SObjectType.getDescribe().getName()`

#### LWC

* Never hardcode `/event/Foo__e`
* Always resolve via Apex
* Centralize PE subscription logic in a utility

If any JS file contains `__e` as a string → it’s a bug.

---

### PHASE 4 — Metadata as policy, not plumbing

Custom Metadata **must not** reference API names.

Good metadata:

* `IntegrationCode`
* `ObservationType`
* `Severity`
* `Retryable`
* `Terminal`

Bad metadata:

* Object names
* Event names
* Field API names

Metadata answers:

> “How should this be interpreted *in this org*?”

---

### PHASE 5 — UI scope (keep it honest)

UI responsibilities:

* timeline
* correlation graph
* filtering
* metadata-based interpretation

UI must not:

* infer business meaning
* trigger retries
* encode integration logic

Think **“observability dashboard”**, not “integration manager”.

---

### PHASE 6 — Public Apex API (final shape)

You only need **one** public entry point:

```java
emit(
  integrationCode,
  observationType,
  correlationId,
  parentEventId,
  context
)
```

Anything more is coupling.

---

## Why this is now *better* than before

By dropping backward compatibility, you get:

* cleaner abstractions
* less code
* less metadata
* fewer assumptions
* easier adoption in other orgs

And — this matters — **a framework that teaches good integration discipline**.

---

## Final recommendation (very direct)

Freeze **this** version as v1.0 of the framework.

From now on:

* no SAP thinking
* no HTTP thinking
* no “success/failure” thinking

Only:

> *events happened — correlate them — interpret them elsewhere*