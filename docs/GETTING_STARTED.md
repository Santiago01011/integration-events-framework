# Getting Started — Integration Events Framework (Core 1.5.0)

Everything you need to install the framework in a new org and start logging integrations.

## Prerequisites

- Salesforce org (Developer, Sandbox, or Production) with API access
- Salesforce CLI (`sf`) v2

## Install

Install the packages in this order — plugin packages depend on the core version pinned below. Substituting a different core version in a plugin's dependency chain is not required; the platform resolves it automatically.

| #   | Package                           | Version | Subscriber Package Version Id |
| --- | --------------------------------- | ------- | ----------------------------- |
| 1   | IntegrationLogsFrameworkv2 (core) | 1.5.0-1 | `04tak000000fjvdAAA`          |
| 2   | IEF_Plugin_TopErrors              | 0.1.0-1 | `04tak000000fjxFAAQ`          |
| 3   | IEF_Plugin_SeverityDonnut         | 0.1.0-2 | `04tak000000fjyrAAA`          |
| 4   | IEF_Plugin_Calendar               | 0.1.0-2 | `04tak000000fk0TAAQ`          |

```bash
sf package install --package 04tak000000fjvdAAA --target-org <ORG_ALIAS> --wait 15 --no-prompt
sf package install --package 04tak000000fjxFAAQ --target-org <ORG_ALIAS> --wait 15 --no-prompt
sf package install --package 04tak000000fjyrAAA --target-org <ORG_ALIAS> --wait 15 --no-prompt
sf package install --package 04tak000000fk0TAAQ --target-org <ORG_ALIAS> --wait 15 --no-prompt
```

The dashboard, LMS channels, evaluation rules (CMDT), and both plugins for the severity/top-errors cards install with the core package. The calendar plugin is optional and can be skipped.

> **Note:** these versions are **beta** (not promoted). They are fine for pilots and sandboxes. For production installs, promote first:
>
> ```bash
> sf package version promote --package 04tak000000fjvdAAA --target-dev-hub <DEV_HUB>
> ```

## Assign permission sets

| Permission set                   | Purpose                                        |
| -------------------------------- | ---------------------------------------------- |
| `Integration_Dashboard_Read`     | View the dashboard, logs, and reports          |
| `Integration_Dashboard_Admin`    | Admin panel: toggle plugins, manage registry   |
| `Integ_PluginIntrospection_Read` | Resolve plugins through the `CallableIEF` seam |

Assign to the integration/admin users in **Setup → Permission Sets** or:

```bash
sf org assign permset --name Integration_Dashboard_Admin --target-org <ORG_ALIAS>
```

## Register an integration

Every logged event carries an `IntegrationCode` that must exist in the `idhIntegration_Definition` custom metadata type. Create one record per integration:

- **Label / DeveloperName**: your integration name
- **IntegrationCode\_\_c**: short unique code (e.g. `ERP_ORDER_SYNC`) — used on every emit and as the kill-switch key
- **Enabled\_\_c**: `true`

Setting `Enabled__c = false` silences that integration everywhere without a code deploy (kill switch, zero SOQL).

## Emit your first event

From anywhere in Apex (trigger, batch, service, queueable):

```apex
IntegrationEventPublisher.emit(
  'ERP_ORDER_SYNC',            // integrationCode — must match a Definition row
  'REQUEST_DISPATCHED',        // observationType — fact-based, matches an Evaluation Rule
  'order-1234-attempt-1',      // correlationId — propagate it across the flow
  null,                        // parentEventId — optional, for parent/child chains
  new Map<String, Object>{
    'orderId' => '801xx0000001234',
    'endpoint' => 'https://erp.example.com/api/orders'
  }
);
```

The payload is a platform event (`IntegrationEvent__e`), persisted as an `Integration_Log__c` record by the framework trigger. Correlated events share the `correlationId`, which is what the dashboard uses to reconstruct an integration flow.

Observation types are evaluated by `idhIntegration_Evaluation_Rule` CMDT rows (installed with the core) to assign severity. Add or edit rules to tune severities for your own observation types.

## View the dashboard

Open the **Integration Health Dashboard** tab (App Launcher). You get:

- Paged, filterable log table with correlation drill-down
- Plugin cards (severity breakdown, top errors) rendered dynamically via LMS
- Registry health card showing composition, plugin status, and contract versions (assign `Integration_Dashboard_Admin` to manage)

## Next steps

- **Action plugins** (async post-processing with retries and dead-lettering): see `docs/ACTION_PLUGINS_AND_RESILIENCE.md`
- **Building card/trigger/service plugins**: see `docs/PLUGIN_DEVELOPMENT.md` and `docs/PLUGIN_ARCHITECTURE.md`
- **Cross-package access to the registry** without a compile-time dependency: use `CallableIEF` (`Type.forName('CallableIEF').newInstance().run(action, params)`)
- **Operational guidance** (retention batch, limits, bulk patterns): see `docs/BEST_PRACTICES.md`
- **Something misbehaving**: see `docs/TROUBLESHOOTING.md`
