# Delta Specs: minimal-core-hardening

> First SDD change — `openspec/specs/` is empty, so all domains are NEW specs.
> Verification: `Jest` = local LWC jest; `Static` = static structure check (grep/AST); `Org` = requires org deploy, deferred to CI.

## Domain: core-hygiene (D7)

### Requirement: Dead Core Code Removed

The core package MUST NOT contain `ihdTrendIndicator`, phantom fetches of severity/top-error aggregates, reads of `message.gridSpan`, or `console.log` calls in production code.

- **[Static]**

#### Scenario: Static sweep passes

- GIVEN the core package source tree
- WHEN scanned for the four dead-code markers
- THEN zero matches are found

#### Scenario: Phantom fetch regression blocked

- GIVEN a card data flow that does not render severity or top-errors
- WHEN the dashboard loads
- THEN no severity/top-errors aggregate fetch is issued

### Requirement: Placeholder Labels Correct

Card placeholders MUST render a meaningful, user-facing label (not a raw key or empty string) whenever a card cannot render.

- **[Jest]**

#### Scenario: Placeholder shows reason

- GIVEN a card whose provider is unavailable
- WHEN the dashboard renders
- THEN the placeholder displays a human-readable label

#### Scenario: Healthy card renders data

- GIVEN a card with a working provider
- WHEN the dashboard renders
- THEN data is shown and no placeholder label appears

### Requirement: Filter Parameter Alignment (C3)

Each card provider MUST either honor the filters passed to it or explicitly document (in ApexDocs/README) that a filter is unsupported; silently ignoring a filter is prohibited.

- **[Static + Org]**

#### Scenario: Honored filter

- GIVEN a provider declaring time-range support
- WHEN called with a time-range filter
- THEN returned aggregates respect the range

#### Scenario: Unsupported filter documented

- GIVEN a provider that ignores a filter
- WHEN its documentation is inspected
- THEN the unsupported filter is explicitly listed

### Requirement: Evaluation-Rule CMDT Relocated (C8)

Pipeline evaluation-rule custom metadata rows MUST live in the core package, so uninstalling the calendar plugin leaves pipeline evaluation config intact.

- **[Org]**

#### Scenario: Calendar uninstalled

- GIVEN core and the calendar plugin installed
- WHEN the calendar plugin is uninstalled
- THEN evaluation-rule rows remain and pipeline evaluation still runs

#### Scenario: No orphan rows after plugin removal

- GIVEN evaluation rows owned by core
- WHEN plugin packages are removed
- THEN no evaluation row references missing plugin metadata (orphans surface via introspection)

### Requirement: Unified Layout Convention (C9)

All LWC bundles in core and plugin packages MUST use the `lwc/` directory convention; no bundle remains under a legacy layout path.

- **[Static]**

#### Scenario: Layout sweep

- WHEN the repo is scanned for bundles outside `lwc/`
- THEN zero bundles are found

### Requirement: Shared Context Parse Module (C7)

Context-data parsing MUST live in one shared core module; duplicate `_parseContextData` implementations are prohibited across packages.

- **[Static + Jest]**

#### Scenario: Single implementation

- WHEN the repo is scanned for `_parseContextData`
- THEN exactly one shared implementation plus imports is found

#### Scenario: Shared module unit-tested

- GIVEN the shared parse module
- WHEN its jest suite runs
- THEN malformed context input yields a safe fallback, not a throw

### Requirement: Publish Exception Type and Plugin-Type Enum (C11)

Event publish failures MUST throw a specific typed exception (not a generic type), and plugin-type references MUST use an enum instead of hardcoded strings.

- **[Static + Org]**

#### Scenario: Publish failure is typed

- WHEN a platform-event publish fails
- THEN the raised exception is the dedicated publish exception type (org-verified)

#### Scenario: No hardcoded plugin-type strings

- WHEN Apex is scanned for plugin-type string literals in branching logic
- THEN zero matches are found; only enum constants are used

## Domain: ief-naming-unification (DN)

> Sequenced between D7 and D6. After DN lands, every `IHD_`/`ihd` identifier in earlier domains reads as its IEF equivalent per the canonical map in design.md.

### Requirement: Zero IHD References Outside Allowlist

The repository MUST contain zero case-insensitive `ihd` references outside the explicit allowlist: `docs/archive/**` and `docs/architecture-study/**` (historical material only — no migration class or migration guide ships with this change).

- **[Static]**

#### Scenario: Sweep passes

- GIVEN the post-DN source tree (`force-app/`, `sfdx-project.json`, `config/`, `translations/`)
- WHEN scanned case-insensitively for `ihd`
- THEN zero matches are found outside the allowlist

#### Scenario: IHD identifier regression blocked

- GIVEN the post-DN repository
- WHEN any file adds a new `ihd`-prefixed identifier or reference
- THEN the sweep fails

### Requirement: Apex Namespace Renamed

All core Apex classes MUST use final `IEF_` names per the canonical map (e.g., `IHD_PluginRegistry` → `IEF_PluginRegistry`, `CallableIHD` → `CallableIEF`); test classes and stubs MUST be renamed or updated in the same unit.

- **[Static]**

#### Scenario: Classes renamed

- WHEN the `classes/` directories are scanned for `IHD_`-prefixed class files
- THEN zero remain and each mapped `IEF_` class exists

#### Scenario: References swept compile-consistently

- WHEN Apex, tests, stubs, and CMDT references are scanned for old class names
- THEN zero references remain outside the allowlist, proving the whole rename lands as one compile-consistent unit

#### Scenario: One-unit compile consistency

- WHEN the DN slice is inspected as a whole
- THEN every renamed class and every file referencing it (Apex, tests, stubs, CMDT `ApexClassName__c` values) are updated together — no intermediate slice state references an old name

### Requirement: Registry CMDT Renamed (Greenfield)

The registry object MUST be `IEF_Plugin__mdt` (field API names unchanged), and `IHD_Plugin__mdt` MUST NOT exist anywhere in source; the rename is a clean source-level breaking change for fresh installs — no data-migration class ships with this change.

- **[Static]**

#### Scenario: Object renamed in source

- WHEN the source tree is scanned for `IHD_Plugin__mdt`
- THEN zero matches are found outside the allowlist and `IEF_Plugin__mdt` exists with unchanged field API names

#### Scenario: Plugin record files retargeted

- WHEN plugin packages are inspected
- THEN their record files target the `IEF_Plugin` type with renamed fullNames

### Requirement: LWC Namespace Unified

All LWC bundles MUST use final names per the canonical map (`ihd*` → `ief*`, `integrationHealthDashboard` → `iefDashboard`, generic shared bundles `ief`-prefixed); already-`ief` bundles keep names; every `c-ihd-*` / `c/ihd*` reference in HTML, JS, jest tests, and mocks MUST be updated in the same unit.

- **[Static + Jest]**

#### Scenario: Bundles renamed

- WHEN LWC directories are scanned for `ihd`-prefixed bundles
- THEN zero remain (`ihdTrendIndicator` is deleted in D7)

#### Scenario: Tests green against new names

- GIVEN renamed components and updated tests and mocks
- WHEN `npm run test:unit` runs
- THEN the suite passes with zero old-name references

### Requirement: Package Names and Directories Corrected

Plugin directories MUST be `force-app/ief-plugin-*`, and `sfdx-project.json` package names MUST read `IEF_Plugin_*` (fixing the `IEF_Plugging_` typo) across package, path, and alias entries; actual 2GP package identity changes are new package versions, org-deferred with DevHub.

- **[Static]**

#### Scenario: Project files consistent

- WHEN `sfdx-project.json` and `config/package-map.json` are scanned for `Plugging` and `ihd-plugin`
- THEN zero matches are found and directory names match package paths

### Requirement: Auxiliary Metadata Renamed

The custom permission, custom labels, and translations MUST move to the IEF namespace (`IHD_Manage_Plugins` → `IEF_Manage_Plugins`, `IHD_Tab_*` / `IHD_System_Pulse` → `IEF_*`), with permission-set and LWC label references updated in the same unit.

- **[Static]**

#### Scenario: Auxiliary sweep

- WHEN `labels/`, `translations/`, `customPermissions/`, and `permissionsets/` are scanned for `IHD_`
- THEN zero matches are found and label references resolve to `IEF_` names

## Domain: plugin-composition-introspection (D6)

### Requirement: Effective Composition Visibility

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

### Requirement: No Silent-Null Caching

`IHD_PluginRegistry` MUST NOT cache an instantiation failure as a silent `null`; failures MUST be recorded with reason and re-attemptable, and consumers MUST see the failure, not a missing card.

- **[Org]**

#### Scenario: Failed instantiation recorded

- GIVEN a plugin class that throws in its constructor
- WHEN the registry resolves it
- THEN the failure and reason are stored and retrievable via composition info

#### Scenario: Recovery after fix

- GIVEN a previously failing plugin that is later fixed
- WHEN the registry re-resolves it
- THEN the plugin becomes active and the stale failure no longer masks it

### Requirement: Registry Row Resolvability

Every registry row MUST resolve to deployed metadata; rows pointing at missing metadata MUST be flagged as orphans in composition info, never crash the query.

- **[Org]**

#### Scenario: Orphan row reported

- GIVEN a registry row referencing an undeployed class
- WHEN composition info is queried
- THEN the row is flagged orphan with reason and remaining rows still resolve

### Requirement: Idempotent Registration

Registering a registry row whose DeveloperName already exists MUST be safe (no duplicate rows, no errors).

- **[Org]**

#### Scenario: Duplicate DeveloperName

- GIVEN an existing registry row
- WHEN registration runs again for the same DeveloperName
- THEN exactly one row remains and no exception is raised

## Domain: core-extraction (D1, Option B)

### Requirement: Aggregates Behind Card Providers

Severity, top-errors, and trend aggregate queries MUST be implemented as `IHD_CardPlugin` providers inside their plugin packages; `IntegrationHealthController`, `IntegrationHealthService`, and their selector MUST contain zero plugin-specific aggregate methods (`getSeverityCounts`, `getTopErrorIntegrations`, trend).

- **[Static + Org]**

#### Scenario: Core is plugin-agnostic

- WHEN core Apex classes are scanned for plugin-specific aggregate methods
- THEN zero matches are found

#### Scenario: Plugin cards still work

- GIVEN severity and top-errors plugins deployed
- WHEN the dashboard loads
- THEN their cards render via providers with correct aggregates

### Requirement: Reference Card Provider

Core MUST ship exactly one reference `IHD_CardPlugin` provider with a real consumer, proving the seam end-to-end per the three-role rule.

- **[Static + Org]**

#### Scenario: Three-role rule satisfied

- WHEN the reference provider is inspected
- THEN it implements `IHD_CardPlugin`, is registered in CMDT, and is rendered by the host dashboard

### Requirement: PluginContext Contract Additive-Only

The `PluginContext` contract MUST change additively only in this slice; existing provider implementations MUST compile and behave unchanged.

- **[Static]**

#### Scenario: Existing providers unbroken

- GIVEN providers written against the current context shape
- WHEN the slice's changes are deployed
- THEN all providers compile and return the same results

## Domain: contract-versioning (D2A)

### Requirement: Contract Version Field

`IHD_Plugin__mdt` MUST declare a `Contract_Version__c` field defaulting to `1.0`, representing the contract baseline, decoupled from the core package version.

- **[Static for field; Org for default]**

#### Scenario: New row defaults

- GIVEN a plugin registry row created without a contract version
- THEN `Contract_Version__c` resolves to `1.0`

### Requirement: Loud Skip on Version Mismatch

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

### Requirement: Additive-Only Contract Evolution

Contract evolution rules MUST be documented: additive changes bump minor, breaking changes bump major and require explicit migration guidance.

- **[Static]**

#### Scenario: Rules documented

- WHEN the contract documentation is inspected
- THEN additive-only evolution and version-bump semantics are stated

## Domain: host-degradation (negative space)

### Requirement: Plugin Failures Never Break the Host

A broken, missing, or version-mismatched plugin MUST NOT prevent host rendering or log ingestion; the affected card shows a placeholder with reason and all other functionality continues.

- **[Jest for host LWC; Org for Apex paths]**

#### Scenario: Broken plugin contained

- GIVEN one provider that throws
- WHEN the dashboard loads
- THEN other cards render, log ingestion succeeds, and the broken card shows a placeholder with reason

#### Scenario: Missing plugin contained

- GIVEN a registry row with no deployed implementation
- WHEN the dashboard loads
- THEN the host renders with a placeholder and no unhandled exception
