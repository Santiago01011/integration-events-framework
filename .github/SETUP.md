# Salesforce CI/CD Setup Guide

This guide documents how to set up CI/CD for Salesforce managed/unlocked packages using GitHub Actions.

## Prerequisites

- DevHub enabled org
- Salesforce CLI installed
- GitHub repository

## Required GitHub Secrets

| Secret                | Description             | How to Get                       |
| --------------------- | ----------------------- | -------------------------------- |
| `DEVHUB_CONSUMER_KEY` | Connected App client ID | See "Create Connected App" below |
| `DEVHUB_SERVER_KEY`   | JWT private key (PEM)   | See "Generate JWT Key" below     |
| `DEVHUB_USERNAME`     | DevHub admin username   | Your DevHub login email          |
| `CI_BYPASS_KEY`       | Secret bypass string    | Create a random secure string    |

## Setup Steps

### 1. Generate JWT Key Pair

```bash
# Generate private key
openssl genrsa -out server.key 2048

# Generate certificate
openssl req -new -x509 -sha256 -key server.key -out server.crt -days 365

# SAVE server.key content as DEVHUB_SERVER_KEY secret
cat server.key
```

### 2. Create Connected App in DevHub

1. **Setup** → **App Manager** → **New Connected App**
2. Fill in:
   - Name: `CI/CD Integration`
   - API Name: `CI_CD_Integration`
   - Enable OAuth Settings: ✅
   - Callback URL: `http://localhost:1717/OauthRedirect`
   - Use digital signatures: ✅ (upload `server.crt`)
   - Scopes: `api`, `refresh_token`, `offline_access`
3. Save and wait 10 minutes
4. Copy **Consumer Key** → Use as `DEVHUB_CONSUMER_KEY` secret

### 3. Pre-Authorize Connected App

Run once locally:

```bash
sf org login jwt --client-id YOUR_CONSUMER_KEY --jwt-key-file server.key --username YOUR_DEVHUB_USERNAME --set-default-dev-hub --alias DevHub
```

### 4. Add GitHub Secrets

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add each secret from the table above

### 5. Copy Workflow Files

Copy these files to your repo:

- `.github/workflows/ci.yml`
- `.github/workflows/release.yml`
- `config/project-scratch-def.json`
- `scripts/local-ci.ps1`

### 6. Enable Branch Protection

1. **Settings** → **Branches** → **Add rule**
2. Branch name: `main`
3. Enable:
   - ✅ Require status checks to pass
   - ✅ Select `validate` as required check

## Usage

### Local Validation (Before Push)

```bash
# Full CI simulation (creates package + scratch org)
npm run ci:local

# Quick mode (scratch org only, skips package creation)
npm run ci:local:quick
```

### Workflow Triggers

| Event        | Workflow    | Effect                             |
| ------------ | ----------- | ---------------------------------- |
| PR to main   | ci.yml      | Validates package                  |
| Push to main | release.yml | Promotes package + creates release |

## Troubleshooting

| Error                 | Cause                        | Fix                                |
| --------------------- | ---------------------------- | ---------------------------------- |
| `403` on release      | Token lacks write permission | Add `permissions: contents: write` |
| `INSUFFICIENT_ACCESS` | FLS denied in tests          | Wrap in try-catch or use mocks     |
| Coverage < 75%        | Missing tests                | Add test coverage                  |
