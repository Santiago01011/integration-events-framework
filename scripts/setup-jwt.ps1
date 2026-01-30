# Automated JWT Certificate Generation
$openSSLPath = "C:\Program Files\Git\usr\bin\openssl.exe"

Write-Host "--- JWT Certificate Generation ---" -ForegroundColor Cyan

if (Test-Path $openSSLPath) {
    Write-Host "Found OpenSSL at: $openSSLPath"
    
    # Generate the certificate
    & $openSSLPath req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 `
      -keyout server.key `
      -out server.crt `
      -subj "/CN=SalesforceCI/O=IntegrationFramework"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nSUCCESS!" -ForegroundColor Green
        Write-Host "Files generated in current directory:"
        Write-Host " - server.key (Private Key): Add this to GitHub Secret 'DEVHUB_SERVER_KEY'" -ForegroundColor Yellow
        Write-Host " - server.crt (Certificate): Upload this to the Salesforce Connected App" -ForegroundColor Yellow
        Write-Host "`nIMPORTANT: Manual steps remaining in Salesforce/GitHub (see docs/CI/CD.md)"
    } else {
        Write-Host "Error generating certificate." -ForegroundColor Red
    }
} else {
    Write-Host "OpenSSL not found at expected Git path." -ForegroundColor Red
    Write-Host "Please run the command manually in Git Bash:"
    Write-Host "openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt -subj '/CN=SalesforceCI/O=IntegrationFramework'"
}
