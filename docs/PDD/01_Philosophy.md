# 🧠 01. Philosophy: The Shift to Package-Driven Development

> "If your package tests require real Order creation in a sandbox, your package boundary is wrong."

## What is Package-Driven Development (PDD)?

Package-Driven Development (PDD) is an architectural shift where Salesforce metadata is organized into **modular, versioned units (packages)** instead of a monolithic "Happy Soup" in the org.

In PDD, the **Source of Truth** is the version control system (Git), not the Salesforce Prod Org.

## The Core Mental Shift

Moving to PDD requires a fundamental change in how we view our metadata:

| Traditional (Org-Based)                                 | Package-Driven (PDD)                                         |
| :------------------------------------------------------ | :----------------------------------------------------------- |
| **Monolith**: Everything is in `force-app/main`.        | **Modular**: Features live in `force-app/feature-name`.      |
| **Deployment**: `sf project deploy start` (overwrite).  | **Installation**: `sf package install` (versioned artifact). |
| **Coupled**: "It works because existing data is there." | **Isolated**: "It works because I defined all dependencies." |
| **Implicit**: Rely on existing org config.              | **Explicit**: Declare everything the code needs.             |

## Why PDD?

### 1. Clear Ownership Boundaries

Packages enforce strict boundaries. You cannot accidentally depend on a field or class that isn't part of your package or explicitly declared as a dependency.

### 2. Repeatable, Safe Deployments

A package version is an **immutable artifact**. Once version `1.2.0` is created and tested, it is exactly the same bits that get installed in UAT and Production. No "forgotten metadata" during deployment.

### 3. Faster Development Cycles

Developers work in **Scratch Orgs** that are spun up in minutes with _only_ the necessary metadata. No more fighting with 10 years of legacy configuration just to fix a single Apex class.

### 4. Regression Detection

Packages come with their own test suites that run _every time_ a version is created. This builds a safety net that travels with the code.

## When to Use PDD?

PDD is not for every single metadata change (e.g., a simple Admin report change). It is ideal for:

- **Business-Critical Logic**: Pricing engines, complex integrations, regulatory calculations.
- **Shared Libraries**: Utility classes used by multiple teams.
- **Independent Features**: A new module (like "Advanced Discounts") that has distinct boundaries.

## Next Steps

Understand the architectural implications of this shift in [02. Architecture](./02_Architecture.md).
