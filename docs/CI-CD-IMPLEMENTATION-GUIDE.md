# CI/CD Implementation Guide

## Overview

This document provides a quick reference for the enhanced CI/CD pipeline with security scanning.

---

## What Changed

### ✅ Added Security Scanning
- **PMD Analysis**: Scans Apex code for security vulnerabilities
- **NPM Audit**: Checks JavaScript dependencies for known vulnerabilities
- **RetireJS**: Scans LWC components for outdated libraries

### ✅ Improved Scratch Org Configuration
- Added `EventLogWaveIntegration` feature
- Added security settings for better test isolation

### ✅ Enhanced Workflows
- **Parallel Jobs**: Security, quality, and package validation run concurrently
- **Better Artifacts**: Scanner results and coverage reports are saved
- **Quality Gate Summary**: Clear pass/fail status for all checks

---

## PMD Configuration - Not Restrictive

### Philosophy
PMD is configured to **provide insights without blocking development**:

- ✅ **Only CRITICAL security issues fail the build** (Priority 1)
- ⚠️ **All other findings are informational** (Priority 3+)
- 📊 **Results shown in PR summary for awareness**

### What Fails the Build (Priority 1)

Only these **critical security vulnerabilities** will block your PR:

1. `ApexInsecureEndpoint` - HTTP instead of HTTPS
2. `ApexOpenRedirect` - Open redirect vulnerability
3. `ApexSOQLInjection` - SOQL injection risk
4. `ApexXSSFromURLParam` - XSS from URL parameters
5. `ApexXSSFromEscapeFalse` - XSS from escape=false
6. `ApexBadCrypto` - Weak cryptography
7. `ApexCSRF` - CSRF vulnerability

### What Shows as Warnings (Priority 3)

These show up in reports but **don't block PRs**:

- Sharing violations (`with sharing` missing)
- CRUD/FLS violations
- DML/SOQL in loops
- Empty catch blocks
- Hardcoded IDs

### What's Disabled

These rules are **completely disabled** to reduce noise:

- Code style rules (naming conventions, braces)
- Documentation requirements (ApexDoc)
- Debug statement warnings
- Variable naming conventions

---

## Using the Workflows

### CI Workflow (Pull Requests)

**Trigger:** Opening or updating a PR to `main` or `develop`

**Jobs:**
1. **security-scan** (3-5 min)
   - PMD critical security check (blocks on issues)
   - PMD all findings (informational)
   - NPM audit (informational)
   - RetireJS scan (informational)

2. **code-quality** (2-3 min)
   - ESLint validation
   - Prettier check
   - LWC unit tests

3. **package-validation** (20-25 min)
   - Create package version
   - Install in scratch org
   - Run Apex tests
   - Verify 85% code coverage

**Total Time:** ~25-30 minutes (with parallel execution)

### Release Workflow (Push to Main)

**Trigger:** Merging PR to `main`

**Steps:**
1. Create release candidate package
2. Promote to production
3. Create GitHub release with install link

---

## Viewing Results

### In Pull Requests

1. **Checks Tab**: See all job statuses
2. **Job Summary**: Expandable results for each job
3. **Artifacts**: Download detailed scanner reports

### PMD Results

Critical issues appear as:
```
❌ Build Failed: Critical security issues found
Priority 1 | ApexSOQLInjection | Line 45 | Potential SOQL injection
```

Informational findings appear as:
```
ℹ️ PMD Findings (Informational)
Priority 3 | ApexSharingViolations | Line 10 | Missing sharing declaration
```

---

## Bypassing Checks (Emergency Only)

### When Appropriate
- Production incident requiring hotfix
- False positive from scanner
- Approved security exception

### How to Bypass

1. **Pre-commit hooks:**
   ```bash
   git commit --no-verify
   ```

2. **Branch protection:**
   - Repository admin can override
   - Requires justification in PR comments

⚠️ **Note:** All bypasses are logged and should be reviewed

---

## Troubleshooting

### Build Failing on PMD

**Check:**
1. Review the specific rule that failed
2. Verify it's a Priority 1 (critical) issue
3. Check if it's a real security vulnerability

**Fix:**
- If valid: Fix the code
- If false positive: Comment in PR for review
- If configuration issue: Update `config/apex-pmd-ruleset.xml`

### Package Creation Timeout

**Issue:** Package creation exceeds 20-minute timeout

**Solutions:**
1. Check DevHub capacity (may be queued)
2. Review test execution time
3. Consider splitting large deployments

### Code Coverage Below 85%

**Issue:** Build fails on coverage check

**Solutions:**
1. Add missing test coverage
2. Review which classes are uncovered
3. Ensure test quality (not just quantity)

---

## Maintenance

### Updating PMD Rules

Edit `config/apex-pmd-ruleset.xml`:

```xml
<!-- Add a new rule -->
<rule ref="category/apex/security.xml/NewRule">
    <priority>1</priority>  <!-- 1=Critical, 3=Warning -->
</rule>

<!-- Disable a rule -->
<!-- <rule ref="category/apex/security.xml/AnnoyingRule" /> -->
```

### Adjusting Severity Thresholds

Edit `.github/workflows/ci-enhanced.yml`:

```yaml
# More strict (fail on Priority 2+)
--severity-threshold 2

# Less strict (fail on Priority 1 only)
--severity-threshold 1
```

---

## Best Practices

### Before Creating a PR

1. **Run local validation:**
   ```bash
   npm run lint
   npm run prettier:verify
   npm run test:unit
   ```

2. **Check pre-commit hooks are working:**
   ```bash
   git commit -m "test"  # Should auto-format
   ```

3. **Review your changes:**
   - Remove debug statements
   - Check for hardcoded values
   - Verify error handling

### During Code Review

1. Check CI results in PR
2. Review PMD informational findings
3. Verify test coverage for new code
4. Look for security implications

### After Merge

1. Verify release workflow succeeded
2. Check package version in GitHub releases
3. Test installation in sandbox
4. Update documentation if needed

---

## Quick Reference

### Workflow Files

| File | Purpose |
|------|---------|
| `.github/workflows/ci-enhanced.yml` | Enhanced CI with security |
| `.github/workflows/ci.yml` | Original CI (still functional) |
| `.github/workflows/release.yml` | Release automation |

### Configuration Files

| File | Purpose |
|------|---------|
| `config/apex-pmd-ruleset.xml` | PMD security rules |
| `config/project-scratch-def.json` | Scratch org definition |
| `package.json` | NPM scripts and dependencies |

### Documentation Files

| File | Purpose |
|------|---------|
| `docs/CI-CD-SECURITY-ANALYSIS.md` | Complete security analysis |
| `docs/CI/CD.md` | Original CI/CD documentation |
| `.github/SETUP.md` | Initial setup guide |

---

## Support

### Common Commands

```bash
# Run local tests
npm run test:unit

# Check code formatting
npm run prettier:verify

# Auto-fix formatting
npm run prettier

# Run linter
npm run lint

# Full local CI simulation
npm run ci:local
```

### Getting Help

1. Check this guide first
2. Review detailed analysis in `docs/CI-CD-SECURITY-ANALYSIS.md`
3. Check workflow logs in GitHub Actions
4. Contact DevOps team for CI/CD issues

---

**Last Updated:** 2026-02-02  
**Version:** 1.0
