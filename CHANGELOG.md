# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - Plugin Architecture Release

### ⚠️ Prerequisites

- [ ] Scratch org definition updated with new plugin permissions
- [ ] Permission Sets created for plugin access
- [ ] Migration guide documented for PRE-plugin users

### ✨ Features

#### Plugin System

- [ ] Dynamic plugin loading via `iefDynamicLoader`
- [ ] Plugin registry with module-scope registration
- [ ] Base shell component `iefPluginCard` for plugin UI consistency
- [ ] LMS-based cross-component notification system
- [ ] Filter context propagation to plugins

#### Calendar Plugin (`ihd-plugin-calendar`)

- [ ] Daily log count aggregation
- [ ] Timezone-aware boundary handling
- [ ] Hover popovers on badge counts
- [ ] Severity badges on calendar days
- [ ] Date offset bug fixes

#### Severity Breakdown Plugin (`ihd-plugin-severity`)

- [ ] Donut chart visualization
- [ ] Severity color mapping (SUCCESS/WARN/ERROR/FATAL/INFO)
- [ ] Click-to-filter integration with dashboard

#### Top Errors Plugin (`ihd-plugin-toperrors`)

- [ ] Top N error integration tracking
- [ ] Error grouping by correlation ID

#### Grid Layout System

- [ ] Configurable grid span per plugin
- [ ] Responsive grid layout support
- [ ] `Grid_Span__c` as restricted picklist (1, 2, 3)

### 🛠️ Improvements

- [ ] Unified registry + module-scope registration pattern
- [ ] `@wire` for MessageContext instead of imperative
- [ ] Removed dead plugin components
- [ ] Permission circuit breaker pattern
- [ ] Calendar date offset fix (SOQL date functions)
- [ ] Reactivity fixes for calendar plugin

### 🐛 Bug Fixes

- [ ] Fix scratch org definition for CI
- [ ] Fix clickable property in mock files
- [ ] Fix clickable property in plugin package stub (was defaulting to true, should be false for LWC compliance)
- [ ] Remove invalid FlexiPage without template
- [ ] Fix duplicate contextData declaration in card implementations
- [ ] Fix calendar date offset bug
- [ ] Remove modal from calendar (simplified UI)
- [ ] Restore Grid_Span\_\_c as restricted picklist

### 🔄 Breaking Changes

- [ ] Plugin components now require `pluginName` context
- [ ] `IntegrationHealthController` methods may have changed signatures
- [ ] Grid_Span\_\_c values restricted to 1, 2, 3

### 📖 Documentation

- [ ] Plugin architecture documentation (`docs/plugins.md` or similar)
- [ ] Update README with plugin system overview
- [ ] Migration guide from PRE-plugin version

### 🔒 Permissions Added

- [ ] `Integ_Dashboard_Read` - Dashboard read access
- [ ] `Integ_Dashboard_Write` - Dashboard write access
- [ ] Plugin-specific permission sets (if any)

### 🧪 Testing

- [ ] All LWC unit tests pass (109/109)
- [ ] All Apex tests pass
- [ ] Package version creation succeeds
- [ ] Plugin integration tests

### 📦 Packages

- [ ] `integration-logs-framework` - Core framework
- [ ] `ihd-plugin-calendar` - Calendar plugin
- [ ] `ihd-plugin-severity` - Severity breakdown plugin
- [ ] `ihd-plugin-toperrors` - Top errors plugin

---

## [Previous] - PRE Plugins Release

_See git history for previous changelog entries_
