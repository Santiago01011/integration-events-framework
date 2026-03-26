# Plugin Development Guide

## Overview

The Integration Events Framework uses a **plugin architecture** where:

- **Core** owns the framework (dashboard, registry, message channel)
- **Plugins** own cards, queries, and org-specific UX
- **Core is agnostic** — it doesn't know about specific plugins
- **Plugins register themselves** via metadata and shells

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CORE PACKAGE                                   │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  integrationHealthDashboard                                        │ │
│  │  - Reads IHD_Plugin__mdt (discovers plugins)                      │ │
│  │  - Subscribes to IEF_Card_Registry LMS channel                    │ │
│  │  - Renders via lwc:is={ctor}                                      │ │
│  │  - Passes PluginContext to cards                                   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  IEF_Card_Registry__c (Lightning Message Channel)                 │ │
│  │  Fields: cardName, cardLabel, action                              │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  iefDynamicLoader (Single Registry)                               │ │
│  │  - registerCard(name, ctor) — plugins call this                   │ │
│  │  - getConstructor(name) — dashboard calls this                    │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Plugin depends on core
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          PLUGIN PACKAGE                                  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  myPluginShell (Registration)                                     │ │
│  │  - Module-scope: registerCard("myCardImpl", ctor)                 │ │
│  │  - connectedCallback: publish via LMS                             │ │
│  │  - Invisible — just triggers registration                         │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  myCardImpl (Implementation)                                      │ │
│  │  - Receives PluginContext via contextData                         │ │
│  │  - Fetches data with filters                                      │ │
│  │  - Renders visualization                                          │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  IHD_Plugin__mdt record (Metadata)                                │ │
│  │  - Self-registration — core discovers via metadata                │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Step-by-Step: Creating a New Plugin

### Step 1: Create the Package Structure

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
│   │   └── myVisualization/  (optional)
│   │       └── ...
│   └── customMetadata/
│       └── IHD_Plugin.My_Card.md-meta.xml
```

### Step 2: Create the Shell Component

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
    // Notify dashboard that this card is registered
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

### Step 3: Create the Card Implementation

**myCardImpl.js:**

```javascript
import { LightningElement, api, track, wire } from "lwc";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext
} from "lightning/messageService";
import IEF_FILTERS_CHANNEL from "@salesforce/messageChannel/IEF_Filters__c";
import myApexMethod from "@salesforce/apex/MyApexController.myApexMethod";

export default class MyCardImpl extends LightningElement {
  // Private storage for contextData
  _contextData = "";

  @track parsedContext = null;
  @track isLoading = true;
  @track hasError = false;
  @track errorMessage = "";
  @track cardData = [];

  @wire(MessageContext)
  messageContext;

  connectedCallback() {
    this._parseAndFetch();
    this._subscribeToFilters();
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

  // Optional: Subscribe to filter changes via LMS
  _subscribeToFilters() {
    if (this.messageContext) {
      subscribe(
        this.messageContext,
        IEF_FILTERS_CHANNEL,
        (message) => this.handleFilterChange(message),
        { scope: APPLICATION_SCOPE }
      );
    }
  }

  handleFilterChange(message) {
    // Update local filters and re-fetch
    if (this.parsedContext) {
      this.parsedContext.filters = {
        ...this.parsedContext.filters,
        ...message.filters
      };
      this._fetchData();
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

### Step 4: Create the Custom Metadata Record

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

### Step 5: Update sfdx-project.json

```json
{
  "package": "IHDP_MyPlugin",
  "path": "force-app/ihd-plugin-myplugin",
  "default": false,
  "versionName": "ver 0.1",
  "versionNumber": "0.1.0.NEXT",
  "dependencies": [
    {
      "package": "IntegrationLogsFrameworkv2"
    }
  ]
}
```

### Step 6: Deploy

1. Deploy core package first
2. Deploy plugin package
3. In App Builder, add the shell to the page
4. The card should automatically appear in the dashboard

---

## PluginContext Contract

When dashboard renders a card, it passes this context via `contextData`:

```javascript
{
  pluginName: "Severity_Card",
  filters: {
    startDate: "2026-03-01",
    endDate: "2026-03-25",
    severity: ["ERROR", "FATAL"],
    integrationCode: null
  },
  location: "dashboard",
  refreshToken: "timestamp",
  capabilities: {
    canExport: true,
    canFilter: true,
    canRefresh: true
  }
}
```

Cards should parse this and use filters when fetching data.

---

## Key Rules

1. **Core does NOT import from plugins** — Dependency is one-way
2. **Module-scope registration** — Call `registerCard()` outside the class
3. **LMS for notification** — Publish on connectedCallback
4. **Filters in context** — Parse and apply when fetching data
5. **Self-registration** — Create your own metadata record
6. **No core edits** — Adding a plugin never modifies core

---

## Existing Examples

- `ihd-plugin-toperrors` — Top Errors Card
- `ihd-plugin-severity` — Severity Breakdown Card

Both follow this exact pattern.
