# Plugin Contract Versioning

This document defines the evolution rules for the Integration Events Framework (IEF) plugin contract.

## Baseline

- Contract baseline is `1.0`, stored per-row in `IEF_Plugin__mdt.Contract_Version__c`.
- Host exposes `IEF_PluginContract.SUPPORTED_MAJOR = 1` and helper `isCompatible(version)`.
- Rows without a value are treated as `1.0` for backwards compatibility.

## Additive-Only Evolution

The `PluginContext` contract and `IEF_CardPlugin` seam are **additive-only** within a major version:

- Adding a new field, new filter key, new plugin type, or new optional parameter is allowed.
- Existing provider implementations continue to compile and behave unchanged after a minor bump.
- No field is removed or renamed, no existing filter key is dropped, and no existing behavior is broken without a major version bump.
- Dashboard's `contextData` JSON shape never removes or renames keys — only adds.
- Providers that ignore an unsupported filter MUST document which filters are unsupported (C3).

This guarantees that a plugin written against `1.0` keeps working on any `1.x` host.

## Minor vs Major Bump Semantics

- **Minor bump** (`1.0 → 1.1`): additive change only. No breaking change, no migration guidance required. Existing rows stay valid; `isCompatible("1.1")` returns true on a `1.x` host.
- **Major bump** (`1.x → 2.0`): breaking change (renamed field, removed capability, changed semantics). Requires explicit migration guidance and opt-in per row. A row declaring `2.0` against a host supporting `1.x` is **skipped** — no instantiation, placeholder renders with a human-readable reason, composition info reports `SKIPPED_VERSION_MISMATCH`, and one `FRAMEWORK_INTERNAL` platform event per skipped row per transaction is emitted.

## Host Behavior on Mismatch

When `IEF_PluginRegistry.resolve(config)` detects a major version mismatch:

- No `Type.forName` instantiation is attempted.
- A `Resolution` with `status = SKIPPED_VERSION_MISMATCH` and `reason` explaining the mismatch is cached for the transaction and returned.
- `IntegrationHealthController.getActiveCardPlugins()` still emits a `PluginInfo` for the row with `reason` populated so the dashboard renders a placeholder.
- `IntegrationHealthController.getCompositionInfo()` reports the row with `SKIPPED_VERSION_MISMATCH` so admins can see why it was skipped.
- One `FRAMEWORK_INTERNAL` / `PLUGIN_SKIPPED_VERSION_MISMATCH` platform event is emitted per skipped row per transaction (never throws into host flow).

Minor version mismatches within the same major are not skipped — they are compatible.

## Authoring Guidance

- New plugins declare `Contract_Version__c = 1.0` unless they intentionally require a newer contract.
- When adding an optional field to `PluginContext`, bump the contract minor version and document the new key as optional.
- When a breaking change is unavoidable, bump major, publish migration notes, and update `IEF_PluginContract.SUPPORTED_MAJOR` in the host. Existing `1.x` rows remain loadable on `1.x` hosts.

## Verification

- Static: `Contract_Version__c` field exists with default `1.0`; `IEF_PluginContract.SUPPORTED_MAJOR` is `1`; this doc contains additive and bump semantics.
- Jest: skipped plugin (mock `SKIPPED` status) renders placeholder with reason while other cards render.
- Org: declaring `2.0` on a `1.x` host skips the plugin loudly with reason and placeholder.
