# Design: Minimal Core Hardening

## Technical Approach

Five sequenced work units on `feature/core-next`, each one revertible PR slice: **D7 hygiene** (no contract change) → **DN IEF naming unification** (owner-locked: full rename to the IEF namespace, see dedicated section) → **D6 composition introspection** → **D1 aggregate extraction** behind `IEF_CardPlugin` + one core reference provider (owner-locked Option B) → **D2A contract version guard** (baseline 1.0, owner-locked). Apex is locally unrunnable: every Apex requirement is verified by a named static structure check and deferred to org/CI; LWC follows strict TDD (`npm run test:unit`). Existing patterns honored: CMDT registry + `Type.forName`, transaction-scoped static caches, controller→service→selector layering, shell/`iefDynamicLoader` LWC composition, `CallableIHD` reflection entry.

## Architecture Decisions

| #   | Decision             | Choice                                                                                                                                                                                                                                                                                                                                                               | Rejected                                          | Rationale                                                                                                                                                      |
| --- | -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | D6 failure recording | `IHD_PluginRegistry` caches a `Resolution` record (instance + status + reason) per ApexClassName, never a bare `null`. Status enum: `ACTIVE`, `ACTIVE_LWC`, `FAILED`, `ORPHAN`, `SKIPPED_VERSION_MISMATCH`                                                                                                                                                           | Keep null + debug log; throw to caller            | Spec forbids silent-null caching; static cache is already per-transaction, so caching a failure for the tx is safe and next tx re-attempts (recovery scenario) |
| 2   | D1 card data path    | Each plugin package ships `XxxCardPlugin implements IHD_CardPlugin` with an `@AuraEnabled static getCardData(Map<String,Object> filters)` facade; instance `getData()` delegates to the same private logic. Card LWCs swap `@salesforce/apex/IntegrationHealthController.getSeverityCounts` → `@salesforce/apex/IEF_SeverityCardPlugin.getCardData`                  | Route everything through core `getCardPluginData` | Cards own their package's Apex (C1 goal); facade accepts `filters`, fixing C3 by construction; one shared code path per plugin                                 |
| 3   | Trend placement      | Hourly-trend aggregate logic folds into the TopErrors provider (`entry.trend`), since `ihdTrendIndicator` (its only consumer) is deleted in D7                                                                                                                                                                                                                       | Keep trend in core; ship a trend-only card        | Spec requires trend out of core; no standalone trend card exists; TopErrors rows already carry a `trend` field                                                 |
| 4   | Reference card       | Core ships `IHD_RegistryHealthCardPlugin` + `ihdRegistryHealthCard` LWC + shell `iefRegistryHealthShell` + CMDT row — renders D6 composition (name, type, status, reason)                                                                                                                                                                                            | Docs-only; severity as reference                  | Genuinely useful admin surface; dogfoods both D6 and the card seam; follows the exact shell/register/`lwc:is` pattern so core stays plugin-agnostic            |
| 5   | D2A skip semantics   | Version check inside registry resolution; mismatched major ⇒ row skipped: no instantiation, `PluginInfo` still emitted with `status='SKIPPED'` + human-readable reason (placeholder renders), one FRAMEWORK_INTERNAL event per row per transaction via `IntegrationEventPublisher`, composition info records `SKIPPED_VERSION_MISMATCH`. Never throws into host flow | Throw `AuraHandledException`; silently ignore     | Spec: loud skip, placeholder, never throw; event + introspection record satisfy "logged reason" without `System.debug`                                         |
| 6   | C7 shared parse      | Core LWC module `lwc/iefPluginContext/iefPluginContext.js` exporting `parseContextData(raw)` → `{ context, error }`; card impls import it exactly like `c/iefDynamicLoader` today                                                                                                                                                                                    | Duplication into a utils class; keep 3 copies     | Mirrors the proven cross-package module import pattern (same namespace, unlocked packages)                                                                     |
| 7   | C11 enum             | `public enum IHD_PluginType { TRIGGER, SERVICE, FIELD, CARD }`; registry/handler use `IHD_PluginType.CARD.name()`                                                                                                                                                                                                                                                    | String constants class                            | AGENTS.md mandates enums over string constants                                                                                                                 |

## Work Unit DN: IEF Naming Unification (owner-locked)

**Sequencing (D7 → DN → D6 → D1 → D2A)**: DN lands after D7 so dead code (`ihdTrendIndicator` + its test) is deleted before renaming — DN touches only live code — and before D6/D1/D2A so their new artifacts (`Resolution`, card providers, reference card, contract guard) are written once against final IEF names instead of created with `IHD_` names and re-renamed. Breaking renames ride the already-deferred package version creation (next major package version). All `IHD_`/`ihd` identifiers in other sections of this document are transitional; the canonical map below governs post-DN.

**Blast radius (amendment time)**: 79 source files match `grep -ri ihd` (64 under `force-app/`); 3 files match `Plugging`.

### Canonical naming map

| Kind                 | Old                                                                                                                                                                                           | New                                                                                                                                                                                                         |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Apex (core)          | `IHD_CardPlugin`, `IHD_TriggerPlugin`, `IHD_ServicePlugin`, `IHD_FieldPlugin`, `IHD_TriggerContext`, `IHD_SObjectHandler`, `IHD_PluginRegistry`, `IHD_FieldDiscovery`                         | Same suffix under `IEF_` (e.g. `IEF_PluginRegistry`)                                                                                                                                                        |
| Apex (misc)          | `CallableIHD` (+Test), `IHD_TestTriggerPluginCapture`; D7-new `IHD_PluginType`, `IHD_PublishException`                                                                                        | `CallableIEF` (+Test), `IEF_TestTriggerPluginCapture`, `IEF_PluginType`, `IEF_PublishException` (D7 may create these directly with final names)                                                             |
| Apex (post-DN units) | `IHD_RegistryHealthCardPlugin`, `IHD_PluginContract`, `ihdRegistryHealthCard`                                                                                                                 | Created directly as `IEF_RegistryHealthCardPlugin`, `IEF_PluginContract`, `iefRegistryHealthCard`                                                                                                           |
| Apex tests/stubs     | `IHD_PluginRegistryTest`, `IHD_FieldDiscoveryTest`, `IHD_SObjectHandlerTest`, `CallableIHDTest`, `TestStub_*`                                                                                 | Renamed / content-updated to IEF equivalents                                                                                                                                                                |
| CMDT object          | `IHD_Plugin__mdt` (record files `IHD_Plugin.*`)                                                                                                                                               | `IEF_Plugin__mdt` — field API names verified clean (no `ihd`-prefixed fields)                                                                                                                               |
| Permission / labels  | `IHD_Manage_Plugins`; `IHD_Tab_*`, `IHD_System_Pulse`                                                                                                                                         | `IEF_Manage_Plugins`; `IEF_*` (`translations/es` updated)                                                                                                                                                   |
| LWC (core)           | `integrationHealthDashboard`, `ihdAdminPanel`, `ihdDetailDrawer`, `ihdEventHub`, `ihdFilters`, `ihdIntegrationSummaryCard`, `ihdStatsCard`, `ihdTable`, `ihdKeyboardGuide`, `ihdSkeletonCard` | `iefDashboard`, `iefAdminPanel`, `iefDetailDrawer`, `iefEventHub`, `iefFilters`, `iefIntegrationSummaryCard`, `iefStatsCard`, `iefTable`, `iefKeyboardGuide`, `iefSkeletonCard`                             |
| LWC (core, generic)  | `lastUpdatedFooter`, `progressBar`, `timeClockPicker`                                                                                                                                         | `iefLastUpdatedFooter`, `iefProgressBar`, `iefTimeClockPicker` (`timeClockUtils`, `utilsLogsApi` keep names; imports updated)                                                                               |
| LWC (plugins)        | `ihdSeverityBreakdown`, `ihdTopErrorIntegrations`                                                                                                                                             | `iefSeverityBreakdown`, `iefTopErrorIntegrations` (`iefSeverityCardImpl`, `iefTopErrorsCardImpl`, `calendarCardImpl` keep names; `c-ihd-*` references updated)                                              |
| Packages             | `force-app/ihd-plugin-{severity,toperrors,calendar}`; `IEF_Plugging_*` in `sfdx-project.json` + `config/package-map.json`                                                                     | `force-app/ief-plugin-*`; `IEF_Plugin_*` (typo fix). 2GP package Ids (`0Ho…`) are immutable — an actual 2GP rename means new package versions, riding the deferred DevHub slice with the next major version |

Already-`ief` bundles (`iefCardPlaceholder`, `iefDynamicLoader`, `iefPluginCard`, `iefPluginContext`) keep names.

### Rollout reality

No existing orgs will be upgraded — all future installs are fresh/greenfield. The IEF rename (including `IHD_Plugin__mdt` → `IEF_Plugin__mdt`) is therefore a clean source-level breaking change riding the next package version: old names simply disappear from source, and no data-migration class, dual-deploy window, retirement release, or FlexiPage re-add guidance ships with this change. An org that had ever installed an old version would need to manually recreate its registry rows after installing the new version; that scenario is out of scope because no such orgs exist.

### Revertibility & verification flags

- Source-only until package version creation: DN reverts via `git revert` of its slice like every unit; no package/org artifact changes in this slice.
- **[Static]** zero-`ihd` sweep (allowlist: `docs/archive/**` and `docs/architecture-study/**` only — no migration artifacts); class/bundle/package/auxiliary renames.
- **[Jest]** updated tests and mocks green (`npm run test:unit`).
- **[Org — deferred]** 2GP rename via new package versions.

### Adjacent discovery (owner call, not blocking)

`idhIntegration_Definition__mdt` and `idhIntegration_Evaluation_Rule__mdt` carry a distinct legacy `idh` prefix (not matched by the `ihd` sweep and not in the locked scope). Full unification would also rename these data contracts and migrate their rows (evaluation rules drive pipeline behavior). Options: fold into DN (one sweep, more data migration) or defer (keeps this slice's sweep definition exact). Deferred by default unless the owner expands scope.

## Data Flow (after D1)

```
IHD_Plugin__mdt ──SOQL──> IHD_PluginRegistry.getConfigs(type)
   └─> resolve(config) ──> Resolution{instance,status,reason}   (D6/D2A checks here)
Controller.getActiveCardPlugins ──> List<PluginInfo> (incl. skipped rows w/ reason)
Dashboard ──> iefDynamicLoader.getConstructor ──> <lwc:component lwc:is> + contextData(PluginContext JSON)
Card LWC (plugin pkg) ──> c/iefPluginContext.parseContextData ──> own-package @AuraEnabled getCardData(filters)
Registry health card (core) ──> getCompositionInfo ──> renders Resolution table
CallableIHD.call ──additive 'getCompositionInfo' action──> same data for ISVs
```

`PluginContext` LWC contract is unchanged (additive-only requirement satisfied: no field renamed/removed).

## Interfaces / Contracts

```apex
// IHD_PluginRegistry (new members)
public class Resolution {
  public Object instance;          // null unless ACTIVE
  public String status;            // ACTIVE | ACTIVE_LWC | FAILED | ORPHAN | SKIPPED_VERSION_MISMATCH
  public String reason;            // human-readable; null when ACTIVE
}
public static Resolution resolve(IHD_Plugin__mdt config);   // replaces getInstance internals
// PluginCompositionEntry wrapper (IntegrationHealthWrappers):
// developerName, label, pluginType, apexClassName, lwcComponentName,
// displayOrder, status, reason, contractVersion
```

```apex
// Per plugin package (severity shown; toperrors identical in shape)
public with sharing class IEF_SeverityCardPlugin implements IHD_CardPlugin {
  @AuraEnabled(cacheable=false)
  public static Object getCardData(Map<String, Object> filters) { ... } // honors filters (C3)
  public Object getData(Map<String, Object> filters) { return getCardData(filters); }
  // getCardName/getCardDescription/getComponentName/getOrder from CMDT-era values
}
// Core reference provider
public class IHD_RegistryHealthCardPlugin implements IHD_CardPlugin {
  // getData ignores filters — documented as unsupported (C3 doc clause)
}
// IHD_PluginContract (core): SUPPORTED_MAJOR = 1
```

CMDT rows updated: severity/toperrors `ApexClassName__c` `'N/A'` → plugin class; new core row `IHD_Plugin.Plugin_Registry_Health` (CARD, `ApexClassName__c=IHD_RegistryHealthCardPlugin`, `LwcComponentName__c=ihdRegistryHealthCard`).

## File Changes

| File                                                                                                                  | Action                                                                                                                                      | Unit     |
| --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| `lwc/ihdTrendIndicator/` (+ test)                                                                                     | Delete                                                                                                                                      | D7       |
| `lwc/integrationHealthDashboard/*.js`                                                                                 | Modify: remove severity/top-errors fetches + imports, `severityCounts`/`topErrors` props, `message.gridSpan` read, `console.log` block      | D7       |
| `lwc/ihdAdminPanel/ihdAdminPanel.js`                                                                                  | Modify: remove `console.log` calls                                                                                                          | D7       |
| `classes/IntegrationHealthWrappers.cls`                                                                               | Modify: add `PluginInfo.label`; add `PluginCompositionEntry`                                                                                | D7/D6    |
| `lwc/integrationHealthDashboard/*.html`                                                                               | Modify: placeholder binds `plugin.label` (now populated) + reason                                                                           | D7       |
| `customMetadata/idhIntegration_Evaluation_Rule.{7 rows}.md-meta.xml`                                                  | Move: calendar pkg → core `customMetadata/`                                                                                                 | D7 (C8)  |
| `main/default/lwc/*` (iefCardPlaceholder, iefDynamicLoader, iefPluginCard)                                            | Move → `lwc/` (C9)                                                                                                                          | D7       |
| `lwc/iefPluginContext/iefPluginContext.js` (+ jest)                                                                   | Create                                                                                                                                      | D7 (C7)  |
| 3 plugin card impls                                                                                                   | Modify: import shared parse                                                                                                                 | D7       |
| `classes/IntegrationEventPublisher.cls`                                                                               | Modify: `throw new IHD_PublishException(message)` (new typed exception)                                                                     | D7 (C11) |
| `classes/IHD_PluginType.cls` (enum), `IHD_PluginRegistry.cls`, `IntegrationLogHandler.cls`                            | Create/Modify: enum replaces string literals                                                                                                | D7 (C11) |
| `classes/IHD_PluginRegistry.cls`                                                                                      | Modify: `Resolution`, `resolve()`, orphan detect (`Type.forName == null`), version check                                                    | D6/D2A   |
| `classes/IntegrationHealthController.cls`                                                                             | Modify: + `getCompositionInfo()`; delete `getSeverityCounts/getTopErrorIntegrations/getHourlyTrend`                                         | D6/D1    |
| `classes/IntegrationHealthService.cls`, `IntegrationHealthSelector.cls`                                               | Modify: delete plugin aggregate methods (`getSeverityCounts`, `getTopErrorIntegrations`, `getHourlyTrend`, `getLogCountsByIntegrationCode`) | D1       |
| `classes/CallableIHD.cls`                                                                                             | Modify: + `'getCompositionInfo'` action (additive)                                                                                          | D6       |
| `ihd-plugin-severity/main/default/classes/IEF_SeverityCardPlugin.cls` (+ move selector logic)                         | Create                                                                                                                                      | D1       |
| `ihd-plugin-toperrors/main/default/classes/IEF_TopErrorsCardPlugin.cls` (+ trend logic)                               | Create                                                                                                                                      | D1       |
| plugin card LWCs                                                                                                      | Modify: call own-package `getCardData(filters)`                                                                                             | D1       |
| `classes/IHD_RegistryHealthCardPlugin.cls`, `lwc/ihdRegistryHealthCard/`, `lwc/iefRegistryHealthShell/`, CMDT row     | Create                                                                                                                                      | D1       |
| `objects/IHD_Plugin__mdt/fields/Contract_Version__c.field-meta.xml` (default `1.0`), `classes/IHD_PluginContract.cls` | Create                                                                                                                                      | D2A      |
| `docs/plugin-contract-versioning.md`                                                                                  | Create: additive-only evolution, minor/major bump semantics                                                                                 | D2A      |
| permission set `Integ_Dashboard_Read` extension or new `Integ_PluginIntrospection_Read` + `Permissions.md`            | Create/Modify per AGENTS.md                                                                                                                 | D6       |

## Testing Strategy

| Requirement                     | Verification                                                                                                                                                                                                                                                                                                                                       |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Dead code removed (4 markers)   | **Static**: `grep -rn "ihdTrendIndicator\|getSeverityCounts\|getTopErrorIntegrations\|message.gridSpan\|console.log" force-app/integration-logs-framework/lwc force-app/integration-logs-framework/classes` ⇒ 0 (excluding plugin packages); **Jest**: dashboard test asserting no severity/topErrors Apex import (mock module, assert not called) |
| Placeholder labels              | **Jest**: dashboard test — mocked `getActiveCardPlugins` returns plugin without registered ctor ⇒ placeholder renders human-readable `label`; healthy case renders card                                                                                                                                                                            |
| Filter alignment (C3)           | **Static**: provider ApexDocs list unsupported filters (reference card); **Org**: provider with time-range filter (deferred)                                                                                                                                                                                                                       |
| CMDT relocated (C8)             | **Static**: 7 rule files under `force-app/integration-logs-framework/customMetadata/`, zero under calendar pkg; **Org**: uninstall scenario (deferred, flagged)                                                                                                                                                                                    |
| Layout unified (C9)             | **Static**: `find force-app/integration-logs-framework/main/default -name "*.js-meta.xml" -path "*lwc*"` ⇒ 0                                                                                                                                                                                                                                       |
| Shared parse (C7)               | **Static**: `grep -rn "_parseContextData" force-app` ⇒ only `iefPluginContext.js` internals + zero copies; **Jest**: malformed/empty/valid context cases, no throw                                                                                                                                                                                 |
| Publish exception + enum (C11)  | **Static**: `IHD_PublishException` declared and thrown in publisher; zero `'TRIGGER'\|'SERVICE'\|'CARD'\|'FIELD'` literals outside enum + CMDT values; **Org**: publish failure path (deferred)                                                                                                                                                    |
| Composition info shape          | **Static**: `getCompositionInfo` exists on controller + wrapper class + CallableIHD action; **Org**: healthy/failing/orphan scenarios (deferred)                                                                                                                                                                                                   |
| No silent-null caching          | **Static**: `getInstance` returns `Resolution`, no `System.debug` in resolve path; **Org**: failing-plugin + recovery (deferred)                                                                                                                                                                                                                   |
| Idempotent registration         | **Org** (deferred): duplicate DeveloperName registration test class shipped for CI                                                                                                                                                                                                                                                                 |
| Aggregates behind providers     | **Static**: `grep -rn "getSeverityCounts\|getTopErrorIntegrations\|getHourlyTrend\|getLogCountsByIntegrationCode" force-app/integration-logs-framework/classes` ⇒ 0; provider classes exist in both plugin pkgs; **Org**: dashboard renders (deferred)                                                                                             |
| Reference provider (three-role) | **Static**: provider implements `IHD_CardPlugin`, CMDT row exists, shell registers `ihdRegistryHealthCard`; **Jest**: `ihdRegistryHealthCard` renders mocked composition entries (active + failed rows)                                                                                                                                            |
| PluginContext additive-only     | **Static**: diff of `contextData` JSON shape in dashboard — no removed/renamed keys; **Jest**: existing card impl tests still pass unchanged                                                                                                                                                                                                       |
| Contract field                  | **Static**: field-meta.xml with `<default>1.0</default>`? (Apex/MDT: `defaultValue` set via field metadata default); **Org**: new-row default (deferred)                                                                                                                                                                                           |
| Loud skip                       | **Static**: version check present in resolve path, publisher call present; **Jest**: dashboard test — skipped plugin ⇒ placeholder with reason, others render (host-degradation scenario)                                                                                                                                                          |
| Host never breaks               | **Jest**: dashboard test — one provider throws ⇒ other cards render, no unhandled error; **Org**: Apex containment paths (deferred)                                                                                                                                                                                                                |
| Zero IHD references (DN)        | **Static**: `grep -ri ihd force-app sfdx-project.json config translations` ⇒ 0 outside allowlist (`docs/archive/**`, `docs/architecture-study/**`); `grep -r Plugging` ⇒ 0; **Jest**: full suite green post-rename                                                                                                                                 |
| Evolution rules documented      | **Static**: `docs/plugin-contract-versioning.md` contains additive-only + bump semantics                                                                                                                                                                                                                                                           |

## Migration / Rollout

No package versions are created (DevHub deferred). Each unit lands as one chained PR slice on `feature/core-next`, revertible via `git revert` of that slice:

1. **D7**: pure deletions/moves; C8 file move deploys rows under core path — in a source-push org the records are keyed by fullName, so ownership moves atomically with the deploy; C9 move is path-only (no name changes, no org impact).
2. **DN**: pure renames in source (classes, CMDT object, LWC bundles, package dirs/names, labels/permission/translations); the old `IHD_Plugin__mdt` object is removed from source in the same slice — no dual-deploy window, no migration class (greenfield-only rollout, see "Rollout reality"); Jest tests/mocks renamed in the same slice.
3. **D6**: additive wrapper + controller method + registry internal rework; `getInstance` callers (`IEF_SObjectHandler`, `CallableIEF`, controller) migrate to `resolve()` in the same slice.
4. **D1**: plugin classes + CMDT `ApexClassName__c` updates deploy with the classes; card LWC Apex imports swap in the same commit so UI and metadata never diverge.
5. **D2A**: field + guard; default `1.0` keeps every existing row valid, so the guard is a no-op until someone declares `2.0`.

Packaged-org caveats (C8 fullName collision if both packages ship the same rule rows; stale dependency pins `1.4.2-1` lacking new core members) are explicitly deferred and flagged in the PR descriptions — source-only verification this slice.

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Risks & Out of Design

| Risk                                                                                        | Mitigation                                                                    |
| ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Cross-package import of `c/iefPluginContext` breaks against stale core pin in packaged orgs | Flagged; pins updated in deferred packaging slice; source orgs unaffected     |
| CMDT rule-row collision during C8 in orgs where calendar package is installed               | Deferred + flagged; introspection surfaces orphans                            |
| `Type.forName` across unlocked packages unproven by any local test (C10 gap)                | Org-deferred test class shipped for CI; static checks prove wiring            |
| Registry health card adds a core card to every dashboard                                    | `CardLocation__c='summary'`, small payload, disableable via CMDT `Enabled__c` |

Out of design: D3 lazy loading, D4 LMS action classification, D5 capability enforcement, admin LMS panel for introspection UI beyond the reference card, package version creation, `IHD_ServicePlugin`/`IHD_FieldPlugin` removal.

## Open Questions

- None blocking. (Org-deferred verifications are enumerated in Testing Strategy, not open questions.)
