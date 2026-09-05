# IEF Package Versions

Last verified: 2026-09-05. Update this file when new versions are cut from the `integration-events-framework` repo (`feature/core-next` or later main).

## Install order and commands

```bash
# 1. Core (required)
sf package install --package 04tak000000fjvdAAA --target-org <ORG_ALIAS> --wait 15 --no-prompt

# 2. Plugins (optional, each depends on core)
sf package install --package 04tak000000fjxFAAQ --target-org <ORG_ALIAS> --wait 15 --no-prompt  # TopErrors card
sf package install --package 04tak000000fjyrAAA --target-org <ORG_ALIAS> --wait 15 --no-prompt  # SeverityDonut card
sf package install --package 04tak000000fk0TAAQ --target-org <ORG_ALIAS> --wait 15 --no-prompt  # Calendar card
```

## Registry

| Package                           | Version | Subscriber Package Version Id |
| --------------------------------- | ------- | ----------------------------- |
| IntegrationLogsFrameworkv2 (core) | 1.5.0-1 | `04tak000000fjvdAAA`          |
| IEF_Plugin_TopErrors              | 0.1.0-1 | `04tak000000fjxFAAQ`          |
| IEF_Plugin_SeverityDonnut         | 0.1.0-2 | `04tak000000fjyrAAA`          |
| IEF_Plugin_Calendar               | 0.1.0-2 | `04tak000000fk0TAAQ`          |

## Notes

- These versions are **beta** (not promoted). Promote before production installs:
  `sf package version promote --package <ID> --target-dev-hub <DEV_HUB>`
- Core ships: dashboard (Integration Health Dashboard tab), `Integration_Log__c`, `IntegrationEvent__e` platform event, `IntegrationEventPublisher`, `CallableIEF`, evaluation-rule CMDT rows, both LMS channels.
- Perm sets: `Integration_Dashboard_Read`, `Integration_Dashboard_Admin`, `Integ_PluginIntrospection_Read`.
