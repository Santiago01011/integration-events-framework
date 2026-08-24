# Spec: Plugin Composition Introspection

> Source: `minimal-core-hardening` (D6) — archived 2026-08-24. First SDD change; `openspec/specs/` was empty.
> Original delta: `openspec/changes/archive/2026-08-24-minimal-core-hardening/spec.md` Domain `plugin-composition-introspection` (D6).

## Requirement: Effective Composition Visibility

The system SHALL expose a `getCompositionInfo`-style Apex data method returning, per registry row: resolved target, card order, instantiation success/failure, and failure reason.

- **[Org — Apex logic; method shape static-checked]**

#### Scenario: All plugins healthy

- GIVEN a registry with resolvable rows
- WHEN composition info is queried
- THEN every row reports resolved target and effective order

#### Scenario: Failing plugin surfaced

- GIVEN a registry row whose Apex class fails to instantiate
- WHEN composition info is queried
- THEN that row reports failed with a human-readable reason

## Requirement: No Silent-Null Caching

`IEF_PluginRegistry` MUST NOT cache an instantiation failure as a silent `null`; failures MUST be recorded with reason and re-attemptable, and consumers MUST see the failure, not a missing card.

- **[Org]**

#### Scenario: Failed instantiation recorded

- GIVEN a plugin class that throws in its constructor
- WHEN the registry resolves it
- THEN the failure and reason are stored and retrievable via composition info

#### Scenario: Recovery after fix

- GIVEN a previously failing plugin that is later fixed
- WHEN the registry re-resolves it
- THEN the plugin becomes active and the stale failure no longer masks it

## Requirement: Registry Row Resolvability

Every registry row MUST resolve to deployed metadata; rows pointing at missing metadata MUST be flagged as orphans in composition info, never crash the query.

- **[Org]**

#### Scenario: Orphan row reported

- GIVEN a registry row referencing an undeployed class
- WHEN composition info is queried
- THEN the row is flagged orphan with reason and remaining rows still resolve

## Requirement: Idempotent Registration

Registering a registry row whose DeveloperName already exists MUST be safe (no duplicate rows, no errors).

- **[Org]**

#### Scenario: Duplicate DeveloperName

- GIVEN an existing registry row
- WHEN registration runs again for the same DeveloperName
- THEN exactly one row remains and no exception is raised

## Implementation Notes (non-normative)

- `IEF_PluginRegistry` caches a `Resolution{instance,status,reason}` per `ApexClassName__c`, never a bare `null`. Statuses: `ACTIVE`, `ACTIVE_LWC`, `FAILED`, `ORPHAN`, `SKIPPED_VERSION_MISMATCH`.
- Resolution is transaction-scoped (static cache); next transaction re-attempts (recovery scenario).
- `PluginCompositionEntry` (in `IntegrationHealthWrappers`): `developerName`, `label`, `pluginType`, `apexClassName`, `lwcComponentName`, `displayOrder`, `status`, `reason`, `contractVersion`.
- `IntegrationHealthController.getCompositionInfo()` and additive `CallableIEF` action `getCompositionInfo` expose the same data.
- Permission set `Integ_PluginIntrospection_Read` governs visibility; see `Permissions.md`.
