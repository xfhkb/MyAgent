# MeshAgent Registry Cleaner
# Removes agent from Programs and Features
# Usage: Run as Administrator
# powershell -ExecutionPolicy Bypass -File clean-registry.ps1

param(
    [string]$ServiceName = "google"
)

# Check admin rights
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[!] This script requires Administrator privileges" -ForegroundColor Red
    exit 1
}

Write-Host "[*] MeshAgent Registry Cleaner" -ForegroundColor Cyan

# Remove from Programs and Features
$uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$ServiceName"
if (Test-Path $uninstallKey) {
    Remove-Item -Path $uninstallKey -Recurse -Force
    Write-Host "[+] Removed '$ServiceName' from Programs and Features" -ForegroundColor Green
} else {
    Write-Host "[*] '$ServiceName' not found in Programs and Features" -ForegroundColor Yellow
}

# Also check for common service names
$commonNames = @("Mesh Agent", "MeshAgent", "meshagent", "google")
foreach ($name in $commonNames) {
    $key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$name"
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force
        Write-Host "[+] Removed '$name' from Programs and Features" -ForegroundColor Green
    }
}

# Remove from 32-bit registry path (on 64-bit systems)
$uninstallKey32 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$ServiceName"
if (Test-Path $uninstallKey32) {
    Remove-Item -Path $uninstallKey32 -Recurse -Force
    Write-Host "[+] Removed '$ServiceName' from 32-bit Programs and Features" -ForegroundColor Green
}

Write-Host "[*] Registry cleanup complete" -ForegroundColor Green
