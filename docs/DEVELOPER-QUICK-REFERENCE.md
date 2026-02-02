# Developer Quick Reference - CI/CD

## 🚀 Quick Start

### Before Committing

```bash
# Format code
npm run prettier

# Check formatting
npm run prettier:verify

# Run linter
npm run lint

# Run tests
npm run test:unit
```

### Pre-commit Hook

Automatically runs on `git commit`:

- ✅ Prettier formatting
- ✅ ESLint validation
- ✅ LWC tests for changed files

Bypass (emergency only):

```bash
git commit --no-verify
```

---

## 🔒 What PMD Checks

### ❌ Will FAIL Your PR (Priority 1)

Only **critical security issues**:

- SOQL Injection
- XSS (Cross-Site Scripting)
- CSRF (Cross-Site Request Forgery)
- Weak Cryptography
- HTTP instead of HTTPS
- Open Redirect vulnerabilities

### ℹ️ Shows as WARNING (Priority 3)

**Informational only - won't block:**

- Missing `with sharing`
- CRUD/FLS violations
- DML/SOQL in loops
- Empty catch blocks
- Hardcoded IDs

### 🚫 NOT Checked

We don't care about:

- Code style
- ApexDoc comments
- Naming conventions
- Debug statements

---

## 📊 CI Workflow Steps

### When You Open a PR

**Step 1: Quick Checks (2-5 min)** ⚡

- Security scan (PMD)
- Code quality (ESLint, Prettier)
- LWC unit tests

If this fails → Fix and push again (quick feedback!)

**Step 2: Package Validation (20-25 min)** 🔧
Only runs if Step 1 passes:

- Create Salesforce package
- Install in scratch org
- Run all Apex tests
- Verify 85% coverage

---

## 🐛 Common Issues & Fixes

### ❌ "PMD: ApexSOQLInjection"

```apex
// ❌ Bad - SOQL injection risk
String query = 'SELECT Id FROM Account WHERE Name = \'' + userInput + '\'';

// ✅ Good - Use binding
String query = 'SELECT Id FROM Account WHERE Name = :userInput';
```

### ❌ "PMD: ApexXSSFromURLParam"

```apex
// ❌ Bad - XSS risk
String value = ApexPages.currentPage().getParameters().get('name');
pageMessage = 'Hello ' + value;

// ✅ Good - Escape output
String value = String.escapeSingleQuotes(
    ApexPages.currentPage().getParameters().get('name')
);
```

### ❌ "ESLint: no-unused-vars"

```javascript
// ❌ Bad
import { unused } from "c/utils";

// ✅ Good - Remove unused import
// (or use it)
```

### ❌ "Coverage below 85%"

```apex
// Add tests for your new code
@isTest
static void testMyNewMethod() {
    // Test logic here
}
```

---

## 📦 Viewing Results

### In GitHub PR

1. Go to **Checks** tab
2. See job status:
   - ✅ Green = Passed
   - ❌ Red = Failed
   - 🟡 Yellow = Running

### Download Artifacts

1. Click failed job
2. Scroll to bottom
3. Download artifacts:
   - `security-scan-results`
   - `lwc-coverage`
   - `package-version-results`

### Job Summary

Each job shows a summary with:

- What was checked
- What failed
- How to fix

---

## 🔧 Local Testing

### Full CI Simulation

```bash
npm run ci:local
```

Creates package + scratch org (takes ~20 min)

### Quick Validation

```bash
npm run ci:local:quick
```

Scratch org only, skips package (takes ~5 min)

### Individual Commands

```bash
# Lint JS
npm run lint

# Format check
npm run prettier:verify

# Auto-fix format
npm run prettier

# LWC tests
npm run test:unit

# LWC coverage
npm run test:unit:coverage
```

---

## 🚨 When Build Fails

### 1. Check Which Job Failed

```
✅ security-scan     → All good
❌ code-quality      → Check ESLint/Prettier/Tests
⏸️ package-validation → Waiting...
```

### 2. Read the Error Message

Click on the red X → Read the log:

```
ESLint Error:
  src/modules/lwc/myComponent.js
  12:5  error  'unused' is defined but never used  no-unused-vars
```

### 3. Fix Locally

```bash
# Fix the issue
vim src/modules/lwc/myComponent.js

# Test the fix
npm run lint

# Commit
git add .
git commit -m "fix: remove unused variable"
git push
```

### 4. Wait for Re-run

CI automatically runs on new push.

---

## 💡 Pro Tips

### Tip 1: Run Linter Before Committing

```bash
npm run lint && git commit
```

Only commits if linter passes.

### Tip 2: Auto-fix Formatting

```bash
npm run prettier
git add .
```

Fixes most formatting issues automatically.

### Tip 3: Test Only Your Changes

```bash
# Jest automatically finds related tests
npm run test:unit -- --findRelatedTests src/lwc/yourComponent/*
```

### Tip 4: Watch Mode for Development

```bash
npm run test:unit:watch
```

Tests re-run on file changes.

### Tip 5: Debug Coverage

```bash
npm run test:unit:coverage
open coverage/lcov-report/index.html
```

See exactly what's not covered.

---

## 📚 Documentation Links

- [Complete Security Analysis](CI-CD-SECURITY-ANALYSIS.md)
- [Implementation Guide](CI-CD-IMPLEMENTATION-GUIDE.md)
- [Optimization Summary](CI-CD-OPTIMIZATION-SUMMARY.md)
- [Workflow Comparison](CI-CD-WORKFLOW-COMPARISON.md)

---

## 🆘 Need Help?

### Common Questions

**Q: Can I bypass PMD for this PR?**  
A: No, but only critical security issues block PRs. If PMD failed, it found a real vulnerability.

**Q: My PR failed on style issues, can I disable that?**  
A: Style rules don't block PRs. If it failed, it's a real security issue (P1).

**Q: How do I run PMD locally?**  
A:

```bash
sf plugins install @salesforce/sfdx-scanner
sf scanner run --target "force-app/**/*.cls" \
  --engine pmd \
  --pmdconfig config/apex-pmd-ruleset.xml
```

**Q: Tests pass locally but fail in CI?**  
A: Scratch org may have different settings. Check:

- Test execution order
- Static resources
- Custom metadata

**Q: Build is taking too long**  
A: Package creation takes 15-20 minutes. This is normal for Salesforce.

---

**Quick Reference Version:** 1.0  
**Last Updated:** 2026-02-02
