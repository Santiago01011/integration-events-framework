# Salesforce CI/CD Setup Guide

This guide covers the current GitHub Actions setup for this repo.

## Required GitHub Secrets

| Secret | Description |
| --- | --- |
| `DEVHUB_CONSUMER_KEY` | Connected App client ID for JWT auth |
| `DEVHUB_SERVER_KEY` | JWT private key (PEM contents) |
| `DEVHUB_USERNAME` | Dev Hub username |
| `CI_BYPASS_KEY` | Emergency branch-policy bypass token |

## Setup Steps

### 1. Generate JWT Key Pair

```bash
openssl genrsa -out server.key 2048
openssl req -new -x509 -sha256 -key server.key -out server.crt -days 365
```

Store the contents of `server.key` in `DEVHUB_SERVER_KEY`.

### 2. Create Connected App in Dev Hub

Create a Connected App with:

- OAuth enabled
- callback URL `http://localhost:1717/OauthRedirect`
- digital signature using `server.crt`
- scopes: `api`, `refresh_token`, `offline_access`

Store the consumer key in `DEVHUB_CONSUMER_KEY`.

### 3. Pre-Authorize the Connected App

```bash
sf org login jwt --client-id YOUR_CONSUMER_KEY --jwt-key-file server.key --username YOUR_DEVHUB_USERNAME --set-default-dev-hub --alias DevHub
```

### 4. Add GitHub Secrets

Add the four required secrets in:

- `Settings -> Secrets and variables -> Actions`

## Current Workflow Files

- `.github/workflows/ci.yml`
- `.github/workflows/promote-release.yml`
- `config/project-scratch-def.json`

## Current Workflow Behavior

### PR validation

- `ci.yml` runs on PRs
- always runs repo quality and scratch-org source preflight
- package artifact validation runs only when explicitly requested

### Manual promotion

- `promote-release.yml` is manual only
- requires:
  - `version_id`
  - `release_notes`
- promotes the given package version
- creates the GitHub release

## Local Usage

```bash
npm run ci:local
npm run ci:local:quick
npm run ci:detect-packages
```

## Notes

- No GitHub App is required for version bump automation anymore.
- The release workflow no longer writes to `main`.
- If you want package artifact validation on a PR, add the label `package-artifact-validation`.
