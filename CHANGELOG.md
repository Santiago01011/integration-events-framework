# Release Notes — Plugin Architecture v2.0

**Release Date:** March 29, 2026  
**Previous Version:** v1.3.15.1

---

## Overview

This release introduces a **fully extensible plugin architecture** for the Integration Events Framework. The dashboard is now a host that dynamically loads plugin cards, enabling teams to build and deploy custom visualizations without modifying the core framework.

> ⚠️ **Breaking Change:** This release requires a scratch org refresh. PRE-plugin users should review the [Migration Guide](#migration-guide) before upgrading.

---

## ✨ New Features

### Plugin System Architecture

The framework now supports **dynamic plugin loading** via a decoupled architecture:

| Component                             | Purpose                                           |
| ------------------------------------- | ------------------------------------------------- |
| `iefDynamicLoader`                    | Discovers and loads plugins at runtime            |
| `iefPluginCard`                       | Base shell for consistent plugin UI               |
| Plugin Registry                       | Module-scope registration with `registerPlugin()` |
| LMS Channel (`IEF_Plugin_Actions__c`) | Cross-component notification                      |

**Key Capabilities:**

- Plugins are independent packages that register themselves to the dashboard
- Filter context (date range, observation type, integration code, correlation ID) propagates to all plugins
- Plugins communicate via Lightning Message Service for filter actions
- Configurable grid layout (1, 2, or 3 column span)

### Plugin Packages

| Package                      | Version | Description                            |
| ---------------------------- | ------- | -------------------------------------- |
| `integration-logs-framework` | 1.4.2-1 | Core framework with plugin host        |
| `ihd-plugin-calendar`        | 0.1.0-1 | Daily log count calendar view          |
| `ihd-plugin-severity`        | 0.1.0-1 | Severity breakdown donut chart         |
| `ihd-plugin-toperrors`       | TBD     | Top N error integrations (coming soon) |

> Note: Grid layout support is built into the core framework (not a separate package).

---

## 🆕 Plugin Details

### Calendar Plugin (`ihd-plugin-calendar`)

Daily log count aggregation with timezone-aware boundary handling.

**Features:**

- Daily log count aggregation with date range filtering
- Timezone-aware boundary handling (properly includes records at day boundaries)
- Hover popovers showing severity breakdown per day
- Severity badges on calendar days (color-coded)
- 90-day rolling date range by default

**Timezone Handling:**

```
System.runAs does NOT change the timezone for DateTime.newInstance() or Date.today().
The controller's query bounds are calculated in the runner's timezone, not the test user's.
We expand the query range by ±1 day and use TimeZone.getOffset() to construct exact UTC times.
```

### Severity Breakdown Plugin (`ihd-plugin-severity`)

Donut chart visualization of log severity distribution.

**Features:**

- Conic-gradient donut chart
- Severity color mapping (SUCCESS/WARN/ERROR/FATAL/INFO)
- Click-to-filter: clicking a severity filters the dashboard
- Legend with counts and percentages
- Loading state with spinner
- Empty state when no data

### Top Errors Plugin (`ihd-plugin-toperrors`) — Coming Soon

Top N error integrations with correlation tracking.

**Planned Features:**

- Configurable top-N selection (default: 10)
- Grouping by correlation ID
- Error trend indicator (up/down vs previous period)

---

## 🛠 Improvements

| #   | Change                                                     | PR  |
| --- | ---------------------------------------------------------- | --- |
| 1   | Unified registry + module-scope registration pattern       | #34 |
| 2   | `@wire` for MessageContext instead of imperative wiring    | #36 |
| 3   | Removed dead plugin components                             | #36 |
| 4   | Permission circuit breaker pattern                         | #36 |
| 5   | Calendar date offset fix (SOQL date functions)             | #37 |
| 6   | Reactivity fixes for calendar plugin                       | #37 |
| 7   | Dynamic plugin card architecture (Shell + Loader pattern)  | #34 |
| 8   | Lightning Message Service for cross-component notification | #34 |
| 9   | Plugin grid span with configurable layout                  | #37 |

---

## 🐛 Bug Fixes

| Issue                                                       | Fix                                       |
| ----------------------------------------------------------- | ----------------------------------------- |
| Scratch org definition missing permissions for CI           | Updated `project-scratch-def.json`        |
| `clickable` property defaulting to `true` in mocks          | Set default to `false` for LWC compliance |
| Invalid FlexiPage without template                          | Removed invalid metadata                  |
| Duplicate `contextData` declaration in card implementations | Removed duplicate property declarations   |
| Calendar date offset bug                                    | Fixed SOQL date function handling         |
| Ternary operator in `tabindex` attribute                    | Replaced with conditional attribute       |

---

## 🔄 Breaking Changes

1. **Plugin components now require `pluginName` context** — Plugins must receive `contextData` containing `pluginName`
2. **`IntegrationHealthController` method signatures** — Some methods may have changed; verify Apex implementations
3. **`Grid_Span__c` values restricted** — Now a restricted picklist with values 1, 2, 3 only

---

## 🔒 Permissions

| Permission Set          | Access                            |
| ----------------------- | --------------------------------- |
| `Integ_Dashboard_Read`  | Read access to dashboard and logs |
| `Integ_Dashboard_Write` | Write access for configuration    |

---

## Migration Guide

### For PRE-Plugin Users

If you're upgrading from a version without plugin support:

1. **Refresh your scratch org** — The new plugin system requires fresh metadata
2. **Assign permission sets** — Users need `Integ_Dashboard_Read` and/or `Integ_Dashboard_Write`
3. **Update dashboard** — The `IntegrationHealthDashboard` page now hosts plugins dynamically
4. **Review filter context** — Plugin implementations should use `contextData` for filter state

### Plugin Registration

To create a new plugin:

```javascript
// In your plugin's JS module
import { registerPlugin } from "c/iefDynamicLoader";

registerPlugin({
  name: "My_Plugin",
  gridSpan: 1,
  icon: "utility:chart",
  cardComponent: "c/myPluginCard",
  shellComponent: "c/myPluginShell"
});
```

---

## 📦 Package Versions

```
integration-logs-framework    1.4.2-1
ihd-plugin-calendar           0.1.0-1
ihd-plugin-severity          0.1.0-1
ihd-plugin-toperrors         TBD
```

---

## 🧪 Testing

- **LWC Unit Tests:** 109 passed ✅
- **Apex Tests:** All passing ✅
- **Package Version Creation:** Succeeds ✅

---

## 📖 Documentation

- `AGENTS.md` — Agent instructions for AI-assisted development
- `project.md` — Project structure and architecture

---

## 🙏 Credits

Contributors: @Santiago01011

PRs merged: #32, #34, #36, #37

---

## Next Steps

- [ ] Release `ihd-plugin-calendar` as 1.0.0 (currently 0.1.0.1)
- [ ] Add more plugin packages
- [ ] Plugin marketplace/discovery system
- [ ] Plugin configuration UI in dashboard
