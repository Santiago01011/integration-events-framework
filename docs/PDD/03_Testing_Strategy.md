# 🧪 03. Testing Strategy: Package Tests vs. Org Tests

One of the most common failure points when adopting Package-Driven Development (PDD) is the
**“Works in Scratch Org, Fails in Sandbox”** problem.

This document explains **why this happens**, and how experienced Salesforce teams solve it.

---

## The Core Problem

- **Scratch Orgs** are pristine. They contain no custom validation rules, no unexpected required fields, and no legacy data.
- **Client Sandboxes** are complex. They include:
  - Validation rules you didn’t write
  - Required fields you don’t control
  - Flows, triggers, and automation with implicit assumptions
  - Data that violates “clean” object creation patterns

If your tests depend on creating a “perfect” `Order` or `OrderItem`, they will pass in a Scratch Org and fail in a Sandbox.

This is not a bug — it’s an environment mismatch.

---

## The Expert Solution: Two Explicit Test Layers

We do **not** attempt to make one test suite run everywhere.
Instead, we deliberately split testing into two distinct layers with different responsibilities.

|                    | Package Tests                               | Org Integration Tests                        |
| ------------------ | ------------------------------------------- | -------------------------------------------- |
| **Location**       | Inside the Package (`force-app/my-package`) | Outside the Package (`force-app/main`)       |
| **Environment**    | Scratch Org (ephemeral)                     | Sandbox / UAT                                |
| **Purpose**        | Validate package logic correctness          | Validate integration with org-specific rules |
| **Data Strategy**  | Mocks, stubs, minimal records               | Real records, real automation                |
| **Execution Time** | Every CI build / Package version creation   | Before release / deployment                  |

---

## 1️⃣ Package Tests (Logic-Only Tests)

These tests verify that **your package code behaves correctly**, independent of any client org configuration.

Characteristics:

- **Avoid** creating real `Order` / `OrderItem` records unless strictly necessary.
- **Prefer** pure services, helper classes, and calculation logic.
- **Use** stubs, test builders, or minimal SObject construction.
- **Test**:
  - Boundary values
  - Null handling
  - Bulk behavior
  - Idempotency

**Golden Rule**
Package tests are executed **only** during:

- Scratch Org validation
- Package version creation

They are **not** intended to run in client Sandboxes.

---

## 2️⃣ Org Integration Tests (Sandbox Validation)

These tests verify that the package **works correctly inside the real org**.

Characteristics:

- **Create real records** (`Account`, `Order`, `OrderItem`, etc.)
- **Trigger Flows, Validation Rules, and Triggers**
- **Assert integration**, not internal package logic

These tests live in:

```
force-app/main
```

They are **not packaged**, and they evolve with the org.

Their purpose is not to re-test package logic, but to confirm:

> “Given this org’s rules and data, does the package integrate correctly?”

---

## Why Package Tests Fail in Sandboxes (And Why That’s OK)

Package tests assume a clean environment.
Sandboxes are not clean.

Examples:

- A validation rule on `Order` requiring `BillingCity`
- A Flow that modifies `Status` on insert
- A trigger that enforces pricing rules

If package tests fail in a Sandbox because of these constraints, **that is expected behavior**.

This does **not** indicate a package defect.

**Correct approach**:

- Trust the package version validated in Scratch Orgs
- Validate org-specific behavior using Org Integration Tests

---

## CI/CD Pipeline Implications

A healthy PDD pipeline looks like this:

1. **Pull Request**
   - Create Scratch Org
   - Deploy package source
   - Run **Package Tests**

2. **Package Version Creation**
   - `sf package version create`
   - Salesforce runs package tests in a temporary Scratch Org

3. **Sandbox Installation**
   - `sf package install`
   - **No tests are executed here**

4. **Sandbox Validation**
   - Run **Org Integration Tests**
   - Validate automation, data, and real-world behavior

See [05. Workflow](./05_Workflow.md) for the full pipeline.

---

## 🧠 Mental Model: The Two Testing Engines

Think of Salesforce testing as **two completely different engines**, even though they both use `@isTest`.

### Engine 1: Package Validation (The Certification Engine)

> "Is this package logically correct in isolation?"

- **Runs in**: A temporary, invisible scratch org during `sf package version create`.
- **Sees**: Only your package source and standard objects.
- **Goal**: Certification.

### Engine 2: Org Safety (The Survivability Engine)

> "Does this org behave safely after changes?"

- **Runs in**: Sandbox, UAT, or Production during deployments or manual runs.
- **Sees**: Validation rules, flows, triggers, and real data.
- **Goal**: Realism.

---

## 🛡️ Deep Dive: The Fear of Failing Tests in Prod

A common fear is: _"If I have package tests in my Prod org and they fail (because they don't know about Org rules), won't that block my deployments or lower my coverage?"_

**The Short Answer: No.**

### 1. Package tests are "Certification Artifacts"

Salesforce treats package tests as proof that the version was once proven correct. Once a package is installed, those tests are **not automatically executed**.

- They do **NOT** run on package install.
- They do **NOT** block metadata deployments.
- They do **NOT** contribute to (or reduce) org code coverage.

### 2. The Golden Rule of Execution

To avoid confusion and false negatives, experienced teams follow this rule:

> **Never use `RunAllTestsInOrg` in a PDD environment.**

Instead, use:

- `RunLocalTests`: This ignores all installed package tests and only runs code you own in `force-app/main`.
- **Specified Tests**: Target only your Org Integration Tests.

### 3. Naming Conventions for Clarity

Use prefixes to distinguish the two layers at a glance:

- `PKG_...`: For internal package tests (Expected to fail in Sandboxes).

---

## 🏁 Summary

> **Package tests prove correctness.  
> Org tests prove survivability.**

Packages provide the _logic_; Orgs provide the _reality_. Keeping them separate is not a hack—it is the only way to scale Salesforce development without creating a fragile, unmaintainable "Happy Soup."
