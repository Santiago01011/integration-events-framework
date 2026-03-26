# Plugin Development Guide

## Quick Start

To create a new plugin, you need:

1. **Shell component** — Registers the card with core
2. **Card implementation** — Fetches data and renders visualization
3. **Metadata record** — Self-registration in IHD_Plugin\_\_mdt
4. **Package dependency** — Declare dependency on core

---

## Step 1: Create Package Structure

```
force-app/ihd-plugin-myplugin/
├── main/default/
│   ├── lwc/
│   │   ├── myPluginShell/
│   │   │   ├── myPluginShell.js
│   │   │   ├── myPluginShell.html
│   │   │   └── myPluginShell.js-meta.xml
│   │   ├── myCardImpl/
│   │   │   ├── myCardImpl.js
│   │   │   ├── myCardImpl.html
│   │   │   └── myCardImpl.js-meta.xml
│   │   └── myVisualization/
│   │       └── ...
│   └── customMetadata/
│       └── IHD_Plugin.My_Card.md-meta.xml
```

---

## Step 2: Create the Shell

The shell is an invisible component that registers your card with the core framework.

**myPluginShell.js:**

```javascript
import { LightningElement, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import IEF_CARD_REGISTRY from "@salesforce/messageChannel/IEF_Card_Registry__c";
import { registerCard } from "c/iefDynamicLoader";
import MyCardImpl from "c/myCardImpl";

// Module-scope registration — executes on import, deterministic
registerCard("myCardImpl", MyCardImpl);

export default class MyPluginShell extends LightningElement {
  @wire(MessageContext)
  messageContext;

  connectedCallback() {
    if (this.messageContext) {
      publish(this.messageContext, IEF_CARD_REGISTRY, {
        cardName: "myCardImpl",
        cardLabel: "My Card",
        action: "register"
      });
    }
  }
}
```

**myPluginShell.html:**

```html
<template></template>
```

**myPluginShell.js-meta.xml:**

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>65.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightning__AppPage</target>
        <target>lightning__RecordPage</target>
        <target>lightning__HomePage</target>
    </targets>
</LightningComponentBundle>
```

---

## Step 3: Create the Card Implementation

The card fetches data and renders a visualization.

**myCardImpl.js:**

```javascript
import { LightningElement, api, track } from "lwc";
import myApexMethod from "@salesforce/apex/MyApexController.myApexMethod";

export default class MyCardImpl extends LightningElement {
  // Private storage for contextData
  _contextData = "";

  @track parsedContext = null;
  @track isLoading = true;
  @track hasError = false;
  @track errorMessage = "";
  @track cardData = [];

  connectedCallback() {
    this._parseAndFetch();
  }

  // Setter for contextData — re-fetches when context changes
  @api
  set contextData(value) {
    this._contextData = value;
    if (this.isConnected) {
      this._parseAndFetch();
    }
  }

  get contextData() {
    return this._contextData;
  }

  _parseAndFetch() {
    this._parseContextData();
    if (!this.hasError) {
      this._fetchData();
    }
  }

  _parseContextData() {
    this.hasError = false;
    this.errorMessage = "";

    if (!this.contextData || this.contextData === "") {
      this.parsedContext = { filters: {} };
      return;
    }

    try {
      this.parsedContext = JSON.parse(this.contextData);
      if (!this.parsedContext.filters) {
        this.parsedContext.filters = {};
      }
    } catch {
      this.hasError = true;
      this.errorMessage = "Invalid context data received";
      this.parsedContext = { filters: {} };
    }
  }

  async _fetchData() {
    this.isLoading = true;
    this.hasError = false;

    try {
      const filters = this.parsedContext?.filters || {};
      const result = await myApexMethod({ filters });
      this.cardData = result || [];
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || "Failed to load data";
      this.cardData = [];
    } finally {
      this.isLoading = false;
    }
  }

  get hasData() {
    return this.cardData && this.cardData.length > 0;
  }

  get cardTitle() {
    return "My Card Title";
  }
}
```

**myCardImpl.html:**

```html
<template>
  <lightning-card title="{cardTitle}">
    <template if:true="{isLoading}">
      <div class="slds-p-around_medium">
        <lightning-spinner
          alternative-text="Loading"
          size="small"
        ></lightning-spinner>
      </div>
    </template>

    <template if:true="{hasError}">
      <div class="slds-text-color_error slds-p-around_medium">
        <p>{errorMessage}</p>
      </div>
    </template>

    <template if:false="{isLoading}">
      <template if:true="{hasData}">
        <!-- Your visualization here -->
        <div class="slds-p-around_medium">
          <p>Data loaded: {cardData.length} items</p>
        </div>
      </template>
      <template if:false="{hasData}">
        <div class="slds-p-around_medium slds-text-color_weak">
          <p>No data available</p>
        </div>
      </template>
    </template>
  </lightning-card>
</template>
```

**myCardImpl.js-meta.xml:**

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>65.0</apiVersion>
    <isExposed>false</isExposed>
</LightningComponentBundle>
```

---

## Step 4: Create Metadata Record

This registers your plugin with the core framework.

**IHD_Plugin.My_Card.md-meta.xml:**

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<CustomMetadata
  xmlns="http://soap.sforce.com/2006/04/metadata"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
>
    <label>My Card</label>
    <protected>false</protected>
    <values>
        <field>PluginType__c</field>
        <value xsi:type="xsd:string">CARD</value>
    </values>
    <values>
        <field>LwcComponentName__c</field>
        <value xsi:type="xsd:string">myCardImpl</value>
    </values>
    <values>
        <field>ApexClassName__c</field>
        <value xsi:type="xsd:string">N/A</value>
    </values>
    <values>
        <field>Enabled__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>DisplayOrder__c</field>
        <value xsi:type="xsd:double">10.0</value>
    </values>
    <values>
        <field>CardLocation__c</field>
        <value xsi:type="xsd:string">both</value>
    </values>
</CustomMetadata>
```

---

## Step 5: Update sfdx-project.json

```json
{
  "versionName": "ver 0.1",
  "versionNumber": "0.1.0.NEXT",
  "path": "force-app/ihd-plugin-myplugin",
  "default": false,
  "package": "IHDP_MyPlugin",
  "versionDescription": "My custom plugin card",
  "dependencies": [
    {
      "package": "04tak000000I5UHAA0"
    }
  ]
}
```

Replace `04tak000000I5UHAA0` with the current core package version ID.

---

## Step 6: Deploy and Test

1. **Deploy core first:**

```bash
sf project deploy start -d force-app/integration-logs-framework -o targetOrg
```

2. **Deploy plugin:**

```bash
sf project deploy start -d force-app/ihd-plugin-myplugin -o targetOrg
```

3. **Add shell to page:**
   - Open App Builder
   - Drag `myPluginShell` onto the page
   - It's invisible — just triggers registration

4. **Verify:**
   - Dashboard should show your card
   - Data should load with filters applied

---

## PluginContext Reference

When the dashboard renders your card, it passes this context:

```javascript
{
  pluginName: "My_Card",              // From metadata DeveloperName
  filters: {
    search: "",                      // Free-text search input
    observationType: "",             // Observation type filter value
    integrationCode: "",             // Selected integration code
    correlationId: "",               // Correlation ID filter
    fromOccurredAt: "2026-03-01T00:00:00.000Z",  // Start date (ISO string) or null
    toOccurredAt: "2026-03-26T23:59:59.999Z"     // End date (ISO string) or null
  },
  location: "dashboard",              // Where card is rendered: "dashboard" | "record" | "app"
  refreshToken: "1711395600000",      // For cache invalidation
  capabilities: {
    canExport: true,
    canFilter: true,
    canRefresh: true
  }
}
```

### TypeScript Interface

Plugin developers can use this interface definition for type safety:

```typescript
/**
 * PluginContext - Contract between dashboard and plugin cards.
 * Passed as JSON string via the `contextData` property.
 */
interface PluginContext {
  /** DeveloperName from IHD_Plugin__mdt */
  pluginName: string;

  /** Current filter state from dashboard */
  filters: {
    /** Free-text search */
    search?: string;
    /** Log observation type filter */
    observationType?: string;
    /** Integration code filter */
    integrationCode?: string;
    /** Correlation ID filter */
    correlationId?: string;
    /** Start date (ISO string) */
    fromOccurredAt?: string | null;
    /** End date (ISO string) */
    toOccurredAt?: string | null;
  };

  /** Where the card is rendered */
  location: "dashboard" | "record" | "app";

  /** Timestamp for change detection */
  refreshToken: string;

  /** Feature flags for card capabilities */
  capabilities: {
    canExport: boolean;
    canFilter: boolean;
    canRefresh: boolean;
  };
}
```

---

## Existing Examples

- `ihd-plugin-toperrors` — Top Errors Card with ranked list visualization
- `ihd-plugin-severity` — Severity Breakdown Card with donut chart

Both follow this exact pattern.

---

## Troubleshooting

| Problem                      | Solution                                                 |
| ---------------------------- | -------------------------------------------------------- |
| Card doesn't appear          | Check that shell is on the page                          |
| "Invalid context data" error | Ensure contextData is valid JSON                         |
| No data loading              | Check Apex method is called with filters                 |
| LWC1188 error                | Add `lightning__dynamicComponent` capability to meta.xml |

---

_Plugin Development Guide — Updated after Lightning Message Service integration_
