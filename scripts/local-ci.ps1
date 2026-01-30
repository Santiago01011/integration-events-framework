<#
.SYNOPSIS
    Mirror the GitHub CI pipeline locally to catch packaging errors before pushing.

.DESCRIPTION
    This script replicates what ci.yml does:
    1. Creates a beta package version (compiles code + runs tests in packaging context)
    2. Creates a fresh scratch org
    3. Installs the package
    4. Runs tests in the clean environment
    5. Cleans up

.EXAMPLE
    .\scripts\local-ci.ps1
    
.EXAMPLE
    .\scripts\local-ci.ps1 -SkipPackage  # Only scratch org validation
#>

param(
    [string]$DevHub = "",      # DevHub alias or username (default: uses default dev hub)
    [switch]$SkipPackage,      # Skip package creation (faster, for quick validation)
    [switch]$KeepOrg,          # Don't delete scratch org after tests
    [int]$WaitMinutes = 20     # How long to wait for package creation
)

# Use 'Continue' to prevent CLI warnings written to stderr from crashing the script
$ErrorActionPreference = "Continue"
$ScratchAlias = "ci-local-test"

# Suppress ALL CLI update warnings and extra output that trigger PowerShell NativeCommandError
$env:SF_SKIP_UPDATE_CHECK = "true"
$env:SF_NO_VERSION_CHECK = "true"
$env:SF_HIDE_RELEASE_NOTES = "true"
$env:SF_HIDE_FOOTER = "true"
$env:SF_LOG_LEVEL = "ERROR" # Only show errors to keep output clean

# Auto-detect DevHub if not provided
if ([string]::IsNullOrWhiteSpace($DevHub)) {
    Write-Host "Detecting default DevHub..." -ForegroundColor DarkGray
    $configRaw = sf config get target-dev-hub --json 2>$null
    if ($LASTEXITCODE -eq 0) {
        $config = $configRaw | ConvertFrom-Json
        if ($config.status -eq 0 -and $config.result[0].value) {
            $DevHub = $config.result[0].value
            Write-Host "Using default DevHub: $DevHub" -ForegroundColor DarkGray
        }
    }
    
    if ([string]::IsNullOrWhiteSpace($DevHub)) {
        Write-Host "❌ No default DevHub found. Please set one with 'sf config set target-dev-hub' or pass -DevHub alias." -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  LOCAL CI SIMULATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Package Version Creation
if (-not $SkipPackage) {
    Write-Host "[1/5] Creating Package Version (this mirrors CI)..." -ForegroundColor Yellow
    Write-Host "      This runs ALL tests in the packaging context.`n" -ForegroundColor DarkGray
    
    $resultRaw = sf package version create `
        --package IntegrationLogsFrameworkv2 `
        --installation-key-bypass `
        --wait $WaitMinutes `
        --code-coverage `
        --target-dev-hub $DevHub `
        --json 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        $result = $resultRaw | ConvertFrom-Json
        Write-Host "`n❌ PACKAGE CREATION FAILED" -ForegroundColor Red
        Write-Host "This is the same error you would see in CI:`n" -ForegroundColor Red
        Write-Host ($result.message) -ForegroundColor Red
        
        if ($result.result.Error) {
            Write-Host "`nDetailed errors:" -ForegroundColor Yellow
            Write-Host ($result.result.Error) -ForegroundColor Red
        }
        exit 1
    }
    
    $result = $resultRaw | ConvertFrom-Json
    $VersionId = $result.result.SubscriberPackageVersionId
    Write-Host "✅ Package version created: $VersionId`n" -ForegroundColor Green
} else {
    Write-Host "[1/5] Skipping package creation (--SkipPackage flag)`n" -ForegroundColor DarkGray
}

# Step 2: Create Fresh Scratch Org
Write-Host "[2/5] Creating fresh scratch org ($ScratchAlias)..." -ForegroundColor Yellow

# Delete if exists from previous run (swallow errors if it doesn't exist)
sf org delete scratch --target-org $ScratchAlias --no-prompt 2>$null | Out-Null

sf org create scratch `
    --definition-file config/project-scratch-def.json `
    --alias $ScratchAlias `
    --duration-days 1 `
    --target-dev-hub $DevHub `
    --wait 10 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create scratch org" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Scratch org created`n" -ForegroundColor Green

# Step 3: Deploy or Install
if ($SkipPackage) {
    Write-Host "[3/5] Deploying source to scratch org..." -ForegroundColor Yellow
    sf project deploy start --target-org $ScratchAlias --source-dir force-app --wait 10 2>$null
} else {
    Write-Host "[3/5] Installing package in scratch org..." -ForegroundColor Yellow
    sf package install `
        --package $VersionId `
        --target-org $ScratchAlias `
        --wait 15 2>$null
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Deploy/Install failed" -ForegroundColor Red
    if (-not $KeepOrg) {
        sf org delete scratch --target-org $ScratchAlias --no-prompt 2>$null | Out-Null
    }
    exit 1
}
Write-Host "✅ Code deployed/installed`n" -ForegroundColor Green

# Step 4: Run Tests
Write-Host "[4/5] Running Apex Tests..." -ForegroundColor Yellow
sf apex run test `
    --target-org $ScratchAlias `
    --test-level RunLocalTests `
    --code-coverage `
    --result-format human `
    --wait 15

$TestResult = $LASTEXITCODE

# Step 5: Cleanup
if (-not $KeepOrg) {
    Write-Host "`n[5/5] Cleaning up scratch org..." -ForegroundColor Yellow
    sf org delete scratch --target-org $ScratchAlias --no-prompt 2>$null | Out-Null
    Write-Host "✅ Scratch org deleted`n" -ForegroundColor Green
} else {
    Write-Host "`n[5/5] Keeping scratch org (--KeepOrg flag)" -ForegroundColor DarkGray
    Write-Host "      To delete later: sf org delete scratch --target-org $ScratchAlias --no-prompt`n" -ForegroundColor DarkGray
}

# Final Result
Write-Host "========================================" -ForegroundColor Cyan
if ($TestResult -eq 0) {
    Write-Host "  ✅ LOCAL CI PASSED - Safe to push!" -ForegroundColor Green
} else {
    Write-Host "  ❌ LOCAL CI FAILED - Fix before pushing!" -ForegroundColor Red
}
Write-Host "========================================`n" -ForegroundColor Cyan

exit $TestResult
