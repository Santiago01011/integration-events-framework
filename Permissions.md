# Permissions

| Permission Set | Purpose | Apex Class Access | Notes |
|---|---|---|---|
| `Integration_Dashboard_Read` | Read-only dashboard access | `IntegrationHealthController` | Read `Integration_Log__c` |
| `Integration_Dashboard_Admin` | Full dashboard admin including registry toggle | `IntegrationHealthController`, `IntegrationEventPublisher`, `IntegrationContextService`, `IntegrationLogHandler` | Custom permission `IEF_Manage_Plugins`; edit/delete `Integration_Log__c` |
| `Integ_PluginIntrospection_Read` | Read plugin composition introspection (`getCompositionInfo`) for health checks and admin UI (D6) | `IntegrationHealthController`, `IEF_PluginRegistry`, `CallableIEF` | Read-only composition info; no data mutation; additive `CallableIEF.getCompositionInfo` action |

## D6 Composition Introspection

- `Integ_PluginIntrospection_Read` grants `getCompositionInfo` on `IntegrationHealthController` and via `CallableIEF` (`getCompositionInfo` action).
- No additional object permissions required beyond `WITH USER_MODE` on `IEF_Plugin__mdt`; row-level access is governed by metadata visibility.
- Assign to users needing health-card or admin introspection without granting `IEF_Manage_Plugins`.
