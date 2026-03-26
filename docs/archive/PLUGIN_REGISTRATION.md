# Card Plugin Registration Guide

> ⚠️ **DEPRECATED** — This document describes the old `ihdPluginHost` pattern which is no longer used.
>
> **Current architecture**: The framework now uses `lwc:is` dynamic rendering with `iefDynamicLoader` for plugin registration.
>
> For current documentation, see:
>
> - `docs/PLUGIN_ARCHITECTURE.md` — Architecture overview
> - `docs/PLUGIN_DEVELOPMENT.md` — Plugin development guide
>
> This file is archived for historical reference only.

---

This guide explains how to register a custom card plugin with the Integration Health Dashboard (IHD) plugin system.

## Overview

The IHD dashboard uses a metadata-driven plugin architecture. Each card plugin is an `IHD_Plugin__mdt` custom metadata record paired with an LWC component that renders the card. Plugins are discovered dynamically and rendered through the `ihdPluginHost` component.

## Prerequisites

- An LWC component implementing the card's visual layout
- An Apex class implementing the `IHD_CardPlugin` interface (for data retrieval)
- A custom metadata record in `IHD_Plugin__mdt`

## Step 1: Create the LWC Component

Create a standard Lightning Web Component that accepts the plugin data as a property.

```javascript
// force-app/.../lwc/myCustomPlugin/myCustomPlugin.js
import { LightningElement, api } from "lwc";

export default class MyCustomPlugin extends LightningElement {
  /** @type {Object} Data returned from IHD_CardPlugin.getData() */
  @api data;

  /** @type {boolean} Loading state from the host */
  @api isLoading = false;
}
```

The component receives:

- `data` — the return value of `IHD_CardPlugin.getData(filters)`
- `isLoading` — whether the host is fetching data

## Step 2: Register in the Component Registry

The `ihdPluginHost` component uses a compile-time component registry (LWC platform constraint: no runtime `lwc:component` for external packages). To register your plugin:

1. Open `force-app/.../lwc/ihdPluginHost/ihdPluginHost.js`
2. Import your component at the top:
   ```javascript
   import MyCustomPlugin from "c/myCustomPlugin";
   ```
3. Add an entry to the `COMPONENT_REGISTRY` map:
   ```javascript
   const COMPONENT_REGISTRY = {
     "c-ihd-severity-breakdown": SeverityBreakdown,
     "c-ihd-top-error-integrations": TopErrorIntegrations,
     "c-my-custom-plugin": MyCustomPlugin // Add your entry here
   };
   ```
4. Add a template block in `ihdPluginHost.html` following the existing pattern:
   ```html
   <!-- My Custom Plugin -->
   <template if:true="{isMyCustomPlugin}">
     <c-my-custom-plugin
       data="{pluginData}"
       is-loading="{isLoading}"
       onpluginclick="{handlePluginClick}"
     ></c-my-custom-plugin>
   </template>
   ```
5. Add a corresponding getter in `ihdPluginHost.js`:
   ```javascript
   get isMyCustomPlugin() {
     return this.pluginName === "c-my-custom-plugin";
   }
   ```

> **For Managed Packages**: External managed packages cannot modify the host component directly. Provide a registration snippet (import + registry entry + template block) in your package documentation for the consumer to add manually, or contribute it via a pull request to the framework repository.

## Step 3: Create the Custom Metadata Record

Create an `IHD_Plugin__mdt` record with these fields:

| Field                 | Value                        | Description                                                           |
| --------------------- | ---------------------------- | --------------------------------------------------------------------- |
| `DeveloperName`       | `MyCustomPlugin`             | Unique API name used as the plugin identifier                         |
| `Label`               | `My Custom Plugin`           | Human-readable name displayed in the dashboard                        |
| `Description__c`      | `Shows custom metrics for X` | Description shown in fallback card and admin UI                       |
| `LwcComponentName__c` | `c-my-custom-plugin`         | Must match the `COMPONENT_REGISTRY` key                               |
| `CardLocation__c`     | `summary`                    | Which dashboard tab renders this card                                 |
| `Enabled__c`          | `true`                       | Whether the plugin is active                                          |
| `Order__c`            | `50`                         | Sort order within the tab (lower = earlier)                           |
| `ApexPluginClass__c`  | `MyCustomPluginData`         | Apex class implementing `IHD_CardPlugin` (optional if data is static) |

### CardLocation\_\_c Picklist Values

The `CardLocation__c` field controls which dashboard tab(s) display the plugin card:

| Value              | Behavior                                      |
| ------------------ | --------------------------------------------- |
| `summary`          | Card appears **only** in the Summary tab      |
| `integrations`     | Card appears **only** in the Integrations tab |
| `both`             | Card appears in **both** tabs                 |
| _(undefined/null)_ | Treated as `both` — card appears in all tabs  |

**Recommendation**: Use `summary` for aggregate/overview cards (severity breakdown, system health). Use `integrations` for per-integration detail cards. Use `both` for cards relevant to both views.

## Step 4: Implement the Apex Data Provider (Optional)

If your card needs dynamic data from Apex, create a class implementing `IHD_CardPlugin`:

```java
/**
 * @description Data provider for the My Custom Plugin card.
 * Implements IHD_CardPlugin to supply data to the dashboard.
 */
public with sharing class MyCustomPluginData implements IHD_CardPlugin {
    /**
     * @description Returns data for the plugin card.
     * @param filters Dashboard filter context (may contain startDate, endDate, severityFilter, etc.)
     * @return Object Data passed to the LWC component's `data` property
     */
    public Object getData(Map<String, Object> filters) {
        // Use filters to scope your query
        String severity = filters != null
            ? (String) filters.get('severityFilter')
            : null;

        // Return any serializable object
        return new Map<String, Object>{
            'totalEvents' => 150,
            'errorCount' => 12,
            'status' => 'healthy'
        };
    }
}
```

### Standard Filter Keys

When the dashboard passes filters, your `getData()` method receives a map with these keys:

| Key               | Type              | Description                   |
| ----------------- | ----------------- | ----------------------------- |
| `search`          | String            | Free-text search input        |
| `observationType` | String            | Observation type filter value |
| `integrationCode` | String            | Selected integration code     |
| `correlationId`   | String            | Correlation ID filter         |
| `fromOccurredAt`  | String (ISO 8601) | Start date for time range     |
| `toOccurredAt`    | String (ISO 8601) | End date for time range       |

All keys may be `null` if the user has not set the corresponding filter.

## Step 5: Add a Permission Set (Optional)

If your plugin should only be visible to certain users, create or update a permission set to include access to the plugin's metadata record and any custom objects/fields it uses.

## Fallback Behavior

If a plugin's `LwcComponentName__c` does not match any entry in `COMPONENT_REGISTRY`, the host renders a fallback card that displays:

- Plugin name (from metadata Label)
- Plugin description
- Component name (for debugging)
- Plugin data as formatted key-value pairs or JSON

This ensures that even unregistered plugins provide visual feedback instead of a blank space.

## Troubleshooting

| Symptom                                         | Cause                                             | Fix                                                                    |
| ----------------------------------------------- | ------------------------------------------------- | ---------------------------------------------------------------------- |
| Card does not appear                            | `Enabled__c` is `false`                           | Set to `true` in metadata                                              |
| Card appears in wrong tab                       | `CardLocation__c` value is incorrect              | Update picklist value                                                  |
| Fallback card renders instead of your component | `LwcComponentName__c` does not match registry key | Verify the metadata value matches the `COMPONENT_REGISTRY` key exactly |
| Data is `null` in the card                      | `ApexPluginClass__c` is blank or class throws     | Check Apex class name and debug logs                                   |
| "Insufficient privileges" on toggle             | User lacks `IHD_Manage_Plugins` permission        | Assign via `Integration_Dashboard_Admin` permission set                |
