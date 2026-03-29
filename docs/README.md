# Documentation Index

Welcome to the Integration Events Framework documentation.

---

## 📚 Documentation

### Core Concepts

| Document                                         | Description                                                     |
| ------------------------------------------------ | --------------------------------------------------------------- |
| [PLUGIN_ARCHITECTURE.md](PLUGIN_ARCHITECTURE.md) | Architecture diagram, registration flow, PluginContext contract |
| [PLUGIN_DEVELOPMENT.md](PLUGIN_DEVELOPMENT.md)   | Step-by-step guide to building a plugin                         |
| [ARCHITECTURE.md](ARCHITECTURE.md)               | High-level system architecture                                  |
| [BEST_PRACTICES.md](BEST_PRACTICES.md)           | Bulkification, event loops, limit management                    |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md)         | Common issues and solutions                                     |

### CI/CD & DevOps

| Document                                                                 | Description              |
| ------------------------------------------------------------------------ | ------------------------ |
| [CI/CD.md](CI/CD.md)                                                     | CI/CD pipeline overview  |
| [CI/packageInfo.md](CI/packageInfo.md)                                   | Package versioning       |
| [CI/Monorepo_Package_CI_Redesign.md](CI/Monorepo_Package_CI_Redesign.md) | Monorepo CI architecture |
| [CI/Package_Driven_Development.md](CI/Package_Driven_Development.md)     | PDD methodology          |
| [CI/shell.md](CI/shell.md)                                               | Shell components         |

### Package-Driven Development

| Document                                                               | Description                        |
| ---------------------------------------------------------------------- | ---------------------------------- |
| [PDD/01_Philosophy.md](PDD/01_Philosophy.md)                           | Core philosophy                    |
| [PDD/02_Architecture.md](PDD/02_Architecture.md)                       | Package boundaries                 |
| [PDD/03_Testing_Strategy.md](PDD/03_Testing_Strategy.md)               | Split testing approach             |
| [PDD/04_Implementation_Patterns.md](PDD/04_Implementation_Patterns.md) | Service locator, resolver patterns |
| [PDD/05_Workflow.md](PDD/05_Workflow.md)                               | Development workflow               |
| [PDD/06_Resources.md](PDD/06_Resources.md)                             | External resources                 |

### Other

| Document                                                                     | Description             |
| ---------------------------------------------------------------------------- | ----------------------- |
| [infinite-scroll-bug.md](infinite-scroll-bug.md)                             | Known bug documentation |
| [PRs/test_failure.md](PRs/test_failure.md)                                   | Test failure analysis   |
| [PRs/plugin-system-and-monorepo-ci.md](PRs/plugin-system-and-monorepo-ci.md) | PR documentation        |

---

## 🚀 Quick Start

1. **Understand the architecture**: Start with [ARCHITECTURE.md](ARCHITECTURE.md)
2. **Build a plugin**: Follow [PLUGIN_DEVELOPMENT.md](PLUGIN_DEVELOPMENT.md)
3. **Deploy to CI**: See [CI/CD.md](CI/CD.md)

---

## 📦 Current Package Versions

| Package                      | Version | Status         |
| ---------------------------- | ------- | -------------- |
| `integration-logs-framework` | 1.4.2-1 | Released       |
| `ihd-plugin-calendar`        | 0.1.0-1 | Released       |
| `ihd-plugin-severity`        | 0.1.0-1 | Released       |
| `ihd-plugin-toperrors`       | TBD     | In development |

---

_Last Updated: 2026-03-29_
