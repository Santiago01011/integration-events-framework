# PR Draft

## Suggested Title

`feat: add plugin package architecture and monorepo CI preflight validation`

## Target Branch

`dev`

## Summary

This PR introduces an extensible plugin architecture for the Integration Events Framework and updates CI/CD to support a 3-package monorepo workflow.

On the product side, the framework can now register and execute plugin behavior through metadata-driven Apex interfaces across trigger, service, field, card, and callable layers. The dashboard was updated to host plugin-backed cards, and dedicated package directories were added for external card implementations.

On the delivery side, CI now detects impacted packages, runs a scratch-org preflight source deployment before any package creation, and only performs package artifact validation when explicitly requested. Promotion remains manual and now only automates the GitHub release step.

## What Changed

- Added metadata-driven plugin interfaces and registry infrastructure in the core package.
- Added plugin-aware trigger, service, field-discovery, callable, and dashboard integration points.
- Added package directories for:
  - `force-app/ihd-plugin-toperrors`
  - `force-app/ihd-plugin-severity`
- Added package impact detection for monorepo CI.
- Reworked PR validation so scratch-org source deployment is the mandatory preflight gate.
- Made package artifact validation opt-in instead of always consuming package-version quota.
- Simplified release promotion so package promotion stays manual and GitHub release generation is automated from the selected `04t`.
- Removed the legacy beta package workflow.
- Updated CI/CD docs to match the new process.

## Why

This change moves the repo from a single-package, source-deploy-oriented pipeline to a package-aware monorepo approach without forcing package version creation on every PR. It also separates cheap correctness checks from limited package artifact checks, which is a better fit for Salesforce package-version limits.

## Reviewer Focus

- Plugin extensibility boundaries in the core package
- Package registration and metadata assumptions
- CI impact detection and package ordering
- Scratch-org preflight behavior versus artifact validation behavior
- Release workflow simplification and removal of version-bump automation

## Validation

Please review the checks attached to this PR. The intended validation flow is:

- Repo quality checks
- Security checks
- Scratch-org preflight deployment
- Apex test execution after preflight deployment
- Optional package artifact validation when the PR is labeled `package-artifact-validation`

## Manual Notes

- Package artifact validation is intentionally opt-in to protect daily package-version limits.
- Promotion is intentionally manual. Use the promotion workflow with:
  - `version_id`
  - `release_notes`
- The new package aliases and dependency entries are managed in `sfdx-project.json`.
- Team workflow discipline still matters:
  - open PRs against `dev`
  - respect branch naming and PR conventions
  - only request artifact validation when packaging confidence is needed

## Risks / Follow-Up

- Mixed core-and-plugin branch validation still relies on manual judgment when a plugin must be validated against a freshly created same-branch core beta.
- The branch name does not reflect the current scope of work; the PR title should carry the real intent.
- Future cleanup may still be useful in older docs or local scripts that assumed a single-package workflow.
