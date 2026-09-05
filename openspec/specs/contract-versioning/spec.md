# Spec: Contract Versioning

> Source: `minimal-core-hardening` (D2A) — archived 2026-08-24. First SDD change; `openspec/specs/` was empty.
> Original delta: `openspec/changes/archive/2026-08-24-minimal-core-hardening/spec.md` Domain `contract-versioning` (D2A).
> Depends on: `plugin-composition-introspection` (`Resolution.status = SKIPPED_VERSION_MISMATCH`).

## Requirement: Contract Version Field

`IEF_Plugin__mdt` MUST declare a `Contract_Version__c` field defaulting to `1.0`, representing the contract baseline, decoupled from the core package version.

- **[Static for field; Org for default]**

#### Scenario: New row defaults

- GIVEN a plugin registry row created without a contract version
- THEN `Contract_Version__c` resolves to `1.0`

## Requirement: Loud Skip on Version Mismatch

When a plugin's declared contract version is incompatible with the host's supported range, the host MUST skip the plugin, log a human-readable reason, and render a placeholder — never throw.

- **[Org]**

#### Scenario: Mismatched plugin skipped loudly

- GIVEN a registry row declaring contract version `2.0` against a host supporting `1.x`
- WHEN the dashboard loads
- THEN the plugin is skipped, a reason is logged, and a placeholder renders

#### Scenario: Matching version loads

- GIVEN a row declaring `1.0`
- WHEN the dashboard loads
- THEN the plugin card renders normally

## Requirement: Additive-Only Contract Evolution

Contract evolution rules MUST be documented: additive changes bump minor, breaking changes bump major and require explicit migration guidance.

- **[Static]**

#### Scenario: Rules documented

- WHEN the contract documentation is inspected
- THEN additive-only evolution and version-bump semantics are stated

## Implementation Notes (non-normative)

- Field: `Contract_Version__c` on `IEF_Plugin__mdt`, type `Number(3,1)`, required, default `1.0`.
- Host constant: `IEF_PluginContract.SUPPORTED_MAJOR = 1` with `isCompatible(String/Decimal)` helpers.
- Version check runs inside `IEF_PluginRegistry.resolve()` before `Type.forName` instantiation. Mismatched major → no instantiation, `Resolution{status=SKIPPED_VERSION_MISMATCH, reason="Contract version mismatch: plugin {name} requires {v} but host supports 1.x"}`, one `FRAMEWORK_INTERNAL` platform event per row per transaction via `IntegrationEventPublisher`, and composition info records `SKIPPED_VERSION_MISMATCH` (visible via `getCompositionInfo` and the reference health card).
- Default `1.0` keeps every existing row valid; the guard is a no-op until a row declares `2.0`.
- Evolution guide: `docs/plugin-contract-versioning.md` (additive-only, minor vs major bump semantics).
- Related: `core-extraction` reference card `IEF_RegistryHealthCardPlugin` renders `SKIPPED_VERSION_MISMATCH` rows in `iefRegistryHealthCard` (order 99, `CardLocation__c='summary'`, disableable via `Enabled__c`); `host-degradation` (archived delta) requires skipped/failed/orphan plugins never break host rendering.
