# CI/CD & Infrastructure for Integration Events Framework

This document describes the current CI/CD model for the package-based monorepo.

## Current State

The repo currently contains three package directories:

- `force-app/integration-logs-framework`
- `force-app/ihd-plugin-severity`
- `force-app/ihd-plugin-toperrors`

CI is split into two validation layers:

1. **Preflight validation**
   - always runs for normal PR validation
   - creates a scratch org
   - deploys core source first
   - deploys additional impacted package source in dependency order
   - runs Apex tests and coverage

2. **Package artifact validation**
   - runs only when explicitly requested
   - creates package versions for directly changed packages
   - stores JSON artifacts from `sf package version create` and `sf package version report`

Promotion is manual.

## Workflows

### `ci.yml`

Trigger:

- `pull_request`
- `workflow_dispatch`

Behavior:

1. Detects impacted packages using `config/package-map.json`.
2. Runs security scanning and repo quality checks.
3. Runs scratch-org source preflight.
4. Optionally runs package artifact validation.

Manual artifact validation options:

- `workflow_dispatch` with `run_package_artifact_validation=true`
- add PR label `package-artifact-validation`

### `promote-release.yml`

Trigger:

- manual only

Inputs:

- `version_id`
- `release_notes`

Behavior:

1. Validates the `04t` format.
2. Uses `sf package version report --json` to fetch package metadata.
3. Promotes the package version.
4. Creates a GitHub release using the provided release notes.

This workflow no longer:

- creates scratch orgs
- runs post-promotion validation
- bumps versions
- commits to `main`
- force-pushes any branch

## Setup Requirements

For the current workflows to run, the repo needs these GitHub secrets:

- `DEVHUB_CONSUMER_KEY`
- `DEVHUB_SERVER_KEY`
- `DEVHUB_USERNAME`
- `CI_BYPASS_KEY`

No GitHub App is required for version bump automation anymore.

## Local Helpers

Useful commands:

```bash
npm run ci:detect-packages
npm run ci:bump-default-package
npm run ci:bump-package -- --package-key plugin-severity --dry-run
```

## Notes

- Source preflight is a budget-protection gate. If preflight fails, package creation should not happen.
- Artifact validation is still intentionally selective to avoid burning daily package-version quota.
- Same-branch plugin validation against a freshly-built core beta is not yet automated.
