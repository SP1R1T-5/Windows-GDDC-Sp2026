# ==============================
# Run Sysprep, we're cloning on prox
# ==============================
Write-Host "`n=== Running Sysprep ===" -ForegroundColor Cyan
$SysprepPath = "C:\Windows\System32\Sysprep\sysprep.exe"

if (Test-Path $SysprepPath) {
    Write-Host "Starting Sysprep with OOBE, Generalize, and Shutdown..." -ForegroundColor Yellow
    Start-Process -FilePath $SysprepPath -ArgumentList "/oobe /generalize /shutdown /quiet" -Wait
    Write-Host "Sysprep completed." -ForegroundColor Green
} else {
    Write-Host "Sysprep not found at '$SysprepPath'." -ForegroundColor Red
}
