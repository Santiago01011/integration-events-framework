# CI/CD Redesign Proposal for 3-Package Monorepo

## Goal

Refactor CI/CD from a single-package workflow into a monorepo-aware pipeline that:

- validates package boundaries instead of only raw source deployment
- builds packages in dependency order
- releases each package independently
- keeps repo-wide quality checks simple and fast
- avoids force-push based version bump automation

## Current Problems

### 1. CI validates source deploy, not packages

Current PR CI creates a scratch org and runs:

```bash
sf project deploy start --target-org ci-scratch
```

That validates the repo as one metadata blob, not as 3 package artifacts.

### 2. Automation is hardcoded to one package

These paths still assume only `IntegrationLogsFrameworkv2` exists:

- `.github/workflows/beta-ci.yml`
- `.github/workflows/promote-release.yml`
- `scripts/local-ci.ps1`
- `scripts/local-package-version.ps1`
- `scripts/bump-version.js`

### 3. Dependency handling is static

Plugin packages depend on a fixed released core `04t...` in `sfdx-project.json`.
That blocks same-branch validation of:

- core changes
- plugin changes depending on new core APIs
- full install order in the same commit

### 4. Promotion validation is not proving the right thing

Installing a promoted package and then running `RunLocalTests` in the scratch org does not meaningfully re-run packaged tests.

### 5. Versioning is too implicit

Only the default package is version-bumped, and the workflow force-pushes to `main`.
That is too risky for a multi-package repo.

## Target Model

Split the pipeline into two concerns:

### A. Repo Quality Pipeline

Runs on every PR.

Purpose:

- formatting
- linting
- LWC unit tests
- static security scanning
- workflow/schema validation

This pipeline is package-agnostic.

### B. Package Build and Install Pipeline

Runs on PRs and on manual release flows.

Purpose:

- detect which package directories changed
- resolve dependency order
- create beta package versions for affected packages
- install them into a clean scratch org in dependency order
- run org-level validation tests where appropriate

This pipeline is package-aware.

The current implementation target is now:

- always run scratch-org source preflight first
- only create package versions when artifact validation is explicitly requested

## Package Inventory

Proposed logical package IDs in the CI layer:

| Key                | Path                                   | Package Alias                | Depends On |
| ------------------ | -------------------------------------- | ---------------------------- | ---------- |
| `core`             | `force-app/integration-logs-framework` | `IntegrationLogsFrameworkv2` | none       |
| `plugin-severity`  | `force-app/ihd-plugin-severity`        | `IHD_Plugin_Severity`        | `core`     |
| `plugin-toperrors` | `force-app/ihd-plugin-toperrors`       | `IHD_Plugin_TopErrors`       | `core`     |

This mapping should live in one machine-readable file, not be repeated across workflows.

Recommended options:

- `config/package-map.json`
- or a small script that derives from `sfdx-project.json`

## Recommended Workflow Set

### 1. `quality.yml`

Trigger:

- `pull_request`
- `workflow_dispatch`

Responsibilities:

- branch policy checks
- `npm ci`
- `npm run prettier:verify`
- `npm run lint`
- `npm run test:unit`
- Salesforce scanner

Output:

- reports only

No packaging logic here.

### 2. `package-pr-validation.yml`

Trigger:

- `pull_request`
- `workflow_dispatch`

Responsibilities:

1. Detect changed package directories.
2. Expand impact set by dependencies.
   - If `core` changes, validate `core + all dependent plugins`.
   - If only `plugin-severity` changes, validate `core install baseline + plugin-severity`.
3. Run scratch-org source preflight first.
   - Deploy `core` first.
   - Deploy remaining impacted package source directories after that in dependency order.
   - Run Apex tests and coverage.
4. Only if artifact validation is explicitly requested, create beta package versions.
5. Install built package versions in dependency order.
6. Run org validation tests only for unpackaged/org-owned code.
7. Publish install matrix and created `04t` IDs as artifacts/summary.

Notes:

- This is the workflow that should replace the current fake `package-validation`.
- Do not deploy `force-app/**` as a monolith in this workflow.
- Source preflight is a budget-protection gate. If preflight fails, do not spend package-version quota.

### 3. `package-beta.yml`

Trigger:

- merge/push to `main`
- manual dispatch with package selector

Responsibilities:

- build beta versions only for changed packages
- if `core` changed, optionally build dependent plugin betas too
- store resulting `04t` IDs in workflow summary and artifact

This replaces the current single-package `beta-ci.yml`.

### 4. `package-promote.yml`

Trigger:

- manual only

Inputs:

- `version_id`
- `release_notes`

Responsibilities:

1. Validate the `version_id`.
2. Fetch package metadata with `sf package version report --json`.
3. Promote that version.
4. Create the GitHub release using manual release notes plus CLI-reported package metadata.

Important:

- promotion remains manual
- no force-push to `main`

### 5. `org-validation.yml`

Optional but recommended later.

Purpose:

- validate unpackaged org integration code
- deploy only non-packaged metadata
- run org-owned integration tests

This is the right place for client-org realism checks, not package build validation.

## Detection Rules

Recommended changed-package logic:

1. Build a list of changed files from the PR diff.
2. Match each file to a package directory.
3. Expand the result by dependency graph.

Examples:

- change in `force-app/integration-logs-framework/**` -> validate `core`, `plugin-severity`, `plugin-toperrors`
- change in `force-app/ihd-plugin-severity/**` -> validate `plugin-severity`
- change in shared workflow or package config files -> validate all packages
- change only in docs -> skip package build workflows

Suggested full-rebuild triggers:

- `sfdx-project.json`
- `.github/workflows/**`
- `config/project-scratch-def.json`
- package-mapping config

## Build Strategy

### PR Validation

Use a two-stage approach:

1. source preflight in scratch org
2. selective package artifact validation only when explicitly requested

For dependency order:

1. build `core`
2. build `plugin-severity`
3. build `plugin-toperrors`

Then install in the same order.

### Current Phase 2 Compromise

The current workflow design can safely:

- source-deploy impacted packages in dependency order
- create package versions only for directly changed packages when explicitly requested

It does not yet rewrite plugin dependency references to use freshly built same-branch core betas.
That means:

- a `core` artifact can be validated correctly
- a plugin-only artifact can be validated against the currently declared released core dependency
- a PR changing both `core` and a plugin still needs a later phase for full same-branch artifact validation

### Why not one giant deploy?

Because package CI should answer:

- does this package compile in package context?
- are dependencies declared correctly?
- can the artifact be installed cleanly?

Raw source deploy does not answer those questions.

## Versioning Strategy

Stop using one generic default-package bump.

Instead:

- version each package independently
- require explicit package selection for release
- update only the selected package directory entry in `sfdx-project.json`

Recommended helper:

```bash
node scripts/bump-package-version.js --package IntegrationLogsFrameworkv2
node scripts/bump-package-version.js --package IHD_Plugin_Severity
node scripts/bump-package-version.js --package IHD_Plugin_TopErrors
```

Rules:

- no automatic force-push to protected branches
- version bumps should happen in a dedicated release PR or release commit
- release workflow may open a PR automatically, but should not rewrite `main`

## Dependency Strategy

Current plugin dependencies point to a fixed released core package ID.

For CI, you need a branch-aware install strategy:

### Option A. Temporary dependency rewrite during CI

During the workflow:

1. build core beta
2. capture generated `04t`
3. rewrite plugin dependency references in a temp copy of `sfdx-project.json`
4. build plugin betas against that fresh core beta

Pros:

- validates true same-branch compatibility

Cons:

- a little more workflow scripting

### Option B. Build core only on core changes, install released core for plugin-only PRs

Pros:

- simpler

Cons:

- misses plugin compatibility against unpublished core changes

Recommendation:

- use Option A for PR validation
- keep released dependency IDs in source control for normal release state

## Test Separation

Adopt two explicit categories:

### Package tests

Run during:

- `sf package version create`

Purpose:

- prove package logic in isolation

### Org validation tests

Run after install in scratch org.

Purpose:

- validate unpackaged orchestration
- validate cross-package wiring
- validate org-specific behavior

Do not treat these as the same test layer.

## Suggested Repo Refactors

### Add

- `config/package-map.json`
- `scripts/detect-changed-packages.js`
- `scripts/bump-package-version.js`
- `scripts/create-package-version.js`
- `scripts/install-package-set.js`

### Replace

- `.github/workflows/ci.yml`
- `.github/workflows/beta-ci.yml`
- `.github/workflows/promote-release.yml`

### Remove or deprecate

- `scripts/bump-version.js`
- single-package assumptions in local packaging scripts
- docs that describe PR CI as package install validation when it is not

## Minimal Migration Plan

### Phase 1

- freeze current release flow except for urgent fixes
- add package map
- add changed-package detection script
- update docs to describe current state honestly

### Phase 2

- replace monolithic PR deploy with package-aware scratch-org source preflight
- add optional package artifact validation after successful preflight
- keep existing beta/promote workflow names if desired, but make them package-aware later

### Phase 3

- replace `bump-version.js` with package-specific version bumping where needed
- keep manual promotion workflow minimal
- remove stale docs and setup assumptions from the old release model

### Phase 4

- optionally add matrix builds and cache optimization
- optionally add org-validation workflow for unpackaged metadata

## Proposed End State

On a PR touching `core`:

1. run repo quality checks
2. build `core` beta
3. build both plugin betas against that beta
4. install all 3 in a scratch org
5. run org-owned validation tests

On a PR touching only `plugin-severity`:

1. run repo quality checks
2. install released `core` baseline or freshly-built `core` depending on policy
3. build/install `plugin-severity`
4. run targeted validation

On release:

1. supply the `04t` version ID
2. supply release notes
3. promote the selected package version
4. create the GitHub release

## Recommendation

The most important change is this:

> Treat the repo as a monorepo orchestrator, not as a single package with extra folders.

If the team only makes one improvement now, make PR validation package-aware and dependency-aware.
That will catch the highest-value failures early and make the later release refactor much safer.
