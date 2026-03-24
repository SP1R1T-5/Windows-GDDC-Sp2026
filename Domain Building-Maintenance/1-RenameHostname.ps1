# ==============================
# Rename Computer
# ==============================

$NewHostname = "DOG-DC#"

Write-Host "`n=== Renaming Computer to '$NewHostname' ===" -ForegroundColor Cyan

if ($env:COMPUTERNAME -ne $NewHostname) {
    Rename-Computer -NewName $NewHostname -Force
    Write-Host "Renamed. Reboot required." -ForegroundColor Green
} else {
    Write-Host "Already named '$NewHostname'. Skipping." -ForegroundColor Gray
}
