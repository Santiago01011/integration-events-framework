# Permissions

This document lists permission sets for the Integration Events Framework (IEF).
Naming pattern: `[AppPrefix]_[Component]_[AccessLevel]` per `AGENTS.md`.

## Core

| Permission Set                           | Purpose                                     | Access                                                                                                |
| ---------------------------------------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `Integ_Dashboard_Read`                   | Dashboard read access                       | Read `Integration_Log__c`, `IEF_Plugin__mdt` (read)                                                   |
| `Integ_Dashboard_Admin`                  | Dashboard admin — manage registry and rules | Manage `IEF_Plugin__mdt`, `idhIntegration_Definition__mdt`, `idhIntegration_Evaluation_Rule__mdt`     |
| `IEF_Manage_Plugins` (Custom Permission) | Gate for enabling/disabling plugins         | Assigned via `Integ_Dashboard_Admin`; checked in `IEF_PluginRegistry` / `IntegrationHealthController` |

## minimal-core-hardening — Upcoming

| Permission Set                   | Purpose                                                               | Status                                                                                                                                                        | Access                                                                                                                |
| -------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `Integ_PluginIntrospection_Read` | Read effective plugin composition (`getCompositionInfo`) — D6 surface | **Placeholder — permission set to be created by Worker A (D6)**. Intended to grant read on `IEF_Plugin__mdt` + Apex `getCompositionInfo` without admin write. | Read `IEF_Plugin__mdt` + `IntegrationHealthController.getCompositionInfo` / `CallableIEF` `getCompositionInfo` action |

> Worker A (`wip/minimal-core-d6`) owns creation of `force-app/integration-logs-framework/permissionsets/Integ_PluginIntrospection_Read.permissionset-meta.xml`. This doc entry is the intended permission; the file lands with that branch.

## Plugin Packages

| Permission Set | Purpose                              | Package                                                              |
| -------------- | ------------------------------------ | -------------------------------------------------------------------- |
| (none yet)     | Plugins rely on core permission sets | `ief-plugin-severity`, `ief-plugin-toperrors`, `ief-plugin-calendar` |

---

_Maintain this file for every new feature per `AGENTS.md`. Do not use `SeeAllData=true` in tests covering permission-gated paths._
