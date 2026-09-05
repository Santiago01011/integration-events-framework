---
name: ief-extend
description: "Trigger: extend IEF, ief custom card, ief action plugin, dashboard plugin development, ief core change, extend integration events framework. Decide when and how to extend IEF: cards, action plugins, or core."
license: Apache-2.0
metadata:
  author: "santiago01011"
  version: "1.0"
---

# IEF Extension Decisions

## Activation Contract

Load when asked to extend the Integration Events Framework: add a dashboard card, an action plugin, a new core capability, or when unsure whether a need requires touching the core.

## Hard Rules

- NEVER extend the core package to serve one domain. Core changes are reserved for cross-domain framework gaps, validated with tests, and shipped as a new package version.
- Plugins are SEPARATE DX packages depending on the core version (see pattern in `force-app/ief-plugin-severity` in the framework repo). A plugin never breaks core; uninstalling it removes only its UI/config.
- Plugin contracts are versioned: declare the contract version a plugin was built against; core skips mismatches loudly (registry health card shows them).
- Action plugins run asynchronously via queueable with retries and dead-lettering. Never use them for synchronous, must-succeed-before-response work.
- New dashboard card plugins must self-register: shell LWC registers in the dynamic loader and publishes via the `IEF_Card_Registry` LMS channel. Core never imports a plugin statically.

## Decision Gates

| Need                                                               | Correct extension                                               | Why                                  |
| ------------------------------------------------------------------ | --------------------------------------------------------------- | ------------------------------------ |
| New domain/integration facts                                       | Emit points + CMDT rows in consuming org (see `ief-emit` skill) | Core is domain-agnostic by design    |
| Score severity differently                                         | `idhIntegration_Evaluation_Rule__mdt` row                       | Zero code                            |
| Silence an integration                                             | `Enabled__c = false` on its Definition row                      | Kill switch, zero SOQL               |
| New dashboard visualization for monitored data                     | Card plugin (separate package)                                  | UI-only, reversible                  |
| Async post-processing of logged events (enrich, notify, remediate) | Action plugin (`IEF_ActionPlugin` + `IEF_ActionDispatcher`)     | Retry/dead-letter semantics included |
| Sync transformation inside the emit path                           | NOT an extension — handle in the consuming org's adapter        | Core path must stay lean             |
| Cross-package registry access without compile-time dep             | `CallableIEF` seam                                              | Documented ISV pattern               |
| Missing capability that multiple domains need                      | Core change → SDD change → new package version                  | Last resort                          |

## Execution Steps

1. Classify the need with the decision table; stop if the row above applies.
2. For card plugins: clone `force-app/ief-plugin-severity` as the reference skeleton; implement `@AuraEnabled static getCardData` (cards own their data); declare contract version; add the shell LWC + dynamic-loader registration; Jest test the card.
3. For action plugins: read `docs/ACTION_PLUGINS_AND_RESILIENCE.md` in the framework repo; implement `IEF_ActionPlugin`; register via CMDT; test retry exhaustion → dead-letter.
4. For core changes: run an SDD change (propose → spec → design → apply → verify → archive) on `feature/core-next`; cut a new package version; update `ief-install` skill versions asset.
5. Validate: full gates (Jest, Apex 100%, clean deploy) before declaring done.

## Output Contract

Return: chosen extension path + rejected alternatives with reasons, files/packages to create, contract versions involved, and validation plan.

## References

- Card plugin skeleton: `force-app/ief-plugin-severity/` (framework repo)
- Framework docs (framework repo): `docs/ACTION_PLUGINS_AND_RESILIENCE.md`, `docs/PLUGIN_DEVELOPMENT.md`, `docs/PLUGIN_ARCHITECTURE.md`, `docs/plugin-contract-versioning.md`
- Durable specs: `openspec/specs/` — composition introspection, contract versioning
- Card/action plugin work happens in a clone of the framework repo; domain wiring in consumer orgs uses the `ief-emit` skill instead
