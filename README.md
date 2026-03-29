# Integration Events Framework (IEF)

![Build Status](https://img.shields.io/badge/build-passing-brightgreen) ![Version](https://img.shields.io/badge/version-2.0-blue) ![Salesforce](https://img.shields.io/badge/salesforce-sfdx-cloud)

**The enterprise-grade observability framework for Salesforce.** Decouple your Apex logging from business interpretation, enable real-time monitoring, and empower admins to manage integration health without a single line of code.

---

## 🚀 Why IEF?

Traditional Salesforce logging is brittle. Developers hardcode "Errors", Logs get buried in Custom Objects, and nobody knows if an integration is actually _healthy_ until a customer complains.

**IEF flips the script:**

- **Decouple Signal from Noise:** Developers emit raw _observations_ (e.g., the code response from a REST request), not judgments.
- **Metadata-Driven Intelligence:** Admins define severity. Is a 404 an Error? A Warning? Or just Info? You decide, in production, instantly.
- **Real-Time "Pulse":** Watch your integrations breathe. Live updates via Platform Events (EMP API).
- **Zero-Code Kill Switches:** Stop a runaway integration from spamming the logs instantly from the dashboard.
- **Extensible Plugin Architecture:** Build custom dashboard cards that plug into the core framework.

---

## 🧩 Plugin Architecture

IEF v2.0 introduces a **plugin system** that enables independent packages to extend the dashboard with custom visualizations.

| Package                      | Description                                    | Version     |
| ---------------------------- | ---------------------------------------------- | ----------- |
| `integration-logs-framework` | Core framework (required)                      | 1.4.2-1     |
| `ihd-plugin-calendar`        | Daily log count calendar with timezone support | 0.1.0-1     |
| `ihd-plugin-severity`        | Severity breakdown donut chart                 | 0.1.0-1     |
| `ihd-plugin-toperrors`       | Top N error integrations                       | Coming soon |

**How it works:**

1. Core dashboard hosts plugins dynamically via `lwc:is`
2. Plugins register themselves at module scope
3. Filter context propagates to all plugins via `contextData`
4. Plugins communicate via Lightning Message Service

📖 **[Plugin Architecture Documentation](docs/PLUGIN_ARCHITECTURE.md)** — Architecture diagram, registration flow, technical details  
📖 **[Plugin Development Guide](docs/PLUGIN_DEVELOPMENT.md)** — Step-by-step guide to building your own plugin

---

## 📊 Visual Observability

### System Pulse

The heartbeat of your ecosystem. See global health, failure rates, and active streams in real-time.

![System Pulse](imgs/image-1-face.png)

### Granular & Grouped Views

Drill down from high-level Groups (e.g., "ERP Systems") to specific Transport methods (e.g., "SAP · Outbound").

![Detailed View](imgs/image-2-summaries-detailed.png)

---

## 💻 Developer Experience

Forget complex logging frameworks. You have **one method** to learn.

```apex
// 1. Emit the raw fact. Don't judge it.
IntegrationEventPublisher.emit(
    'SAP_ORDER_SYNC',      // Integration Code (Identity)
    'HTTP_503',            // Observation (Fact)
    'CORR-ID-998877',      // Correlation ID (Traceability)
    null,                  // Parent ID (Optional)
    new Map<String, Object>{ 'endpoint' => 'api.sap.com', 'retry' => 3 } // Context
);
```

**That's it.** The framework handles the rest:

- Asynchronous formatting
- Platform Event publishing
- Deduplication & buffering (if configured)

---

## 🛡 Admin Empowerment

Admins are no longer helpless spectators. Use the **Admin Panel** to manage registry and rules directly.

### 1. The Kill Switch ⚡

Bad code implementing an infinite loop? External API down and spamming errors?
**Disable the integration instantly** from the UI. The framework blocks events _at the source_, saving your limits.

### 2. Semantic Mapping

Map technical signals to business reality using Custom Metadata:

- `HTTP_200` → ✅ **Success**
- `HTTP_203` → 🟡 **Warning**
- `HTTP_500` → 🔴 **Error**

![Admin Panel](imgs/image-4-admin-panel.png)

---

## 📦 Installation

### Core Package (Required)

We publish a new Unlocked Package version for every release. You can find the installation link for the latest version on GitHub.

👉 **[Get the Latest Release](https://github.com/Santiago01011/integration-events-framework/releases/latest)**

### Post-Install Checklist

1.  **Assign Permission Sets**:
    - `Integration_Dashboard_Admin` (For configuring rules)
    - `Integration_Dashboard_Read` (For viewing logs)
2.  **Add to UI**: Drag the `integrationHealthDashboard` LWC onto any App Page or create a LWC tab.
3.  **Schedule Cleanup**: Keep your storage lean.
    ```apex
    // Execute in Developer Console
    System.schedule('IED Daily Cleanup', '0 0 2 * * ?', new IntegrationLogCleanupBatch());
    ```

### Plugin Packages (Optional)

Install individual plugin packages to add dashboard visualizations:

```bash
# Install core first
sf package install --package 04tak000000PWkfAAG --target-org myOrg

# Then install plugins
sf package install --package 04tak000000PWmHAAW --target-org myOrg  # Severity Breakdown
sf package install --package 04tak000000PWsjAAG --target-org myOrg  # Calendar
```

---

## 🔗 Resources

- **[Plugin Architecture](docs/PLUGIN_ARCHITECTURE.md)** - How plugins work
- **[Plugin Development](docs/PLUGIN_DEVELOPMENT.md)** - Build your own plugin
- **[Best Practices](docs/BEST_PRACTICES.md)** - Bulkification, event loops, and limit management
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

---

## 📄 License

This project is provided as-is for use in Salesforce orgs.
