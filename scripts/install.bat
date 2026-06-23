@echo off
:: MeshAgent Silent Installer
:: Run as Administrator

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] This script requires Administrator privileges
    echo [*] Right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo [*] MeshAgent Silent Installer
echo.

:: Ask for admin credentials
set /p ADMIN_USER="Enter MeshCentral admin username (default: admin): "
if "%ADMIN_USER%"=="" set ADMIN_USER=admin
set /p ADMIN_PASS="Enter MeshCentral admin password: "

if "%ADMIN_PASS%"=="" (
    echo [!] Password is required for automatic MeshID retrieval
    pause
    exit /b 1
)

:: Run PowerShell installer with auto-retrieval
echo [*] Starting installation with auto-retrieval...
powershell -ExecutionPolicy Bypass -WindowStyle Hidden -Command "& '%~dp0stealth-install.ps1' -AdminUser '%ADMIN_USER%' -AdminPass '%ADMIN_PASS%'"

echo.
echo [*] Installation complete!
pause
