---
name: ief-install
description: "Trigger: install IEF, install integration events framework, setup integration framework org, ief package install. Install IEF packages, perm sets, and verify the dashboard in an org."
license: Apache-2.0
metadata:
  author: "santiago01011"
  version: "1.0"
---

# IEF Install & Org Setup

## Activation Contract

Load when asked to install the Integration Events Framework in a Salesforce org, set up its packages/permission sets, or verify a working installation.

## Hard Rules

- Install packages in order: core first, then plugins. Never install a plugin whose core dependency version is absent.
- Assign permission sets BEFORE granting dashboard access. The dashboard throws unhandled errors for users without `Integration_Dashboard_Read` (observed: ~60 errors in a fresh org).
- Plugin packages are optional. Only install plugins the user asked for; core is sufficient for logging.
- Never fabricate Subscriber Package Version IDs. Read them from `assets/versions.md`; if a newer version was cut, update that file.
- Run every install command with `--no-prompt` to avoid interactive hangs.

## Execution Steps

1. Read `assets/versions.md` for current package IDs and commands.
2. Identify target org alias. Ask only if absent.
3. Install core, then each requested plugin (`sf package install --package <ID> --target-org <ALIAS> --wait 15 --no-prompt`).
4. Assign permission sets: `Integration_Dashboard_Read` (view), `Integration_Dashboard_Admin` (admin panel), `Integ_PluginIntrospection_Read` (CallableIEF seam) — via `sf org assign permset`.
5. Verify installation:
   - `sf package list --target-org <ALIAS>` shows all packages.
   - Create one `idhIntegration_Definition__mdt` row if none exists (use `assets/sample-definition.md`).
   - Publish a test event via `sf apex run` with `IntegrationEventPublisher.emit(...)`, then confirm an `Integration_Log__c` record exists.
6. Tell the user to open the Integration Health Dashboard tab and confirm cards render.

## Output Contract

Return: packages installed (name + version + ID), perm sets assigned, verification result (log record created: yes/no), and any skipped optional plugin with the reason.

## References

- `assets/versions.md` — package IDs and install commands (update when new versions are cut)
- `assets/sample-definition.md` — minimal `idhIntegration_Definition__mdt` row
- `docs/GETTING_STARTED.md` — human-readable onboarding guide
