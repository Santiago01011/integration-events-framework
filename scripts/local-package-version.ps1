# Create a new beta package version locally
param(
    [switch]$SkipValidation,
    [string]$DevHub = "LWCIntLogs"
)

$packageArgs = @(
    "sf", "package", "version", "create",
    "--package", "IntegrationLogsFrameworkv2",
    "--installation-key-bypass",
    "--wait", "20",
    "--target-dev-hub", $DevHub
)

if (-not $SkipValidation) {
    $packageArgs += "--code-coverage"
}

Write-Host "Creating package version for IntegrationLogsFrameworkv2..." -ForegroundColor Cyan
& $packageArgs[0] $packageArgs[1..($packageArgs.Length-1)]
