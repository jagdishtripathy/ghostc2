@echo off
setlocal enabledelayedexpansion

REM GhostC2 Windows Setup Script
REM This script helps set up the GhostC2 environment on Windows

echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                 GhostC2 Windows Setup Script                 ║
echo ║                                                              ║
echo ║  This script will help you set up GhostC2 for testing       ║
echo ║                                                              ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.

REM Check if we're in the right directory
if not exist "server\main.go" (
    echo [!] This script must be run from the GhostC2 project root directory
    echo [!] Please navigate to the ghostc2 folder and run this script again
    pause
    exit /b 1
)

echo [*] Checking prerequisites...

REM Check if Go is installed
go version >nul 2>&1
if errorlevel 1 (
    echo [!] Go is not installed. Please install Go 1.19 or higher.
    echo [!] Download from: https://golang.org/dl/
    pause
    exit /b 1
)

for /f "tokens=3" %%i in ('go version') do set GO_VERSION=%%i
echo [*] Found Go version: %GO_VERSION%

REM Check if PowerShell is available
powershell -Command "Get-Host" >nul 2>&1
if errorlevel 1 (
    echo [!] PowerShell is not available. Windows agent will not work.
) else (
    echo [+] PowerShell is available
)

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    python3 --version >nul 2>&1
    if errorlevel 1 (
        echo [!] Python is not installed. Python agent will not be available.
    ) else (
        echo [+] Python 3 is available
    )
) else (
    echo [+] Python is available
)

echo [*] Setting up agent scripts...

REM Check if tasks.json exists
if not exist "server\tasks.json" (
    echo [] > server\tasks.json
    echo [+] Created tasks.json file
)

echo [*] Checking Go modules...
if exist "go.mod" (
    echo [*] Go modules already initialized
) else (
    echo [*] Initializing Go modules...
    go mod init ghostc2
    if errorlevel 1 (
        echo [!] Failed to initialize Go modules
        pause
        exit /b 1
    )
    echo [+] Initialized Go modules
)

echo [*] Building server...
go build -o ghostc2.exe server\main.go
if errorlevel 1 (
    echo [!] Failed to build server
    pause
    exit /b 1
)
echo [+] Server built successfully

echo.
echo ══════════════════════════════════════════════════════════════
echo [+] GhostC2 setup completed successfully!
echo.
echo [*] Next steps:
echo    1. Start the server: ghostc2.exe
echo    2. Open your browser to: http://localhost:8080
echo    3. Login with: ghostc2 / ghostc2
echo    4. Run agents on target systems:
echo       - Windows: powershell -ExecutionPolicy Bypass -File agents\windows_agent.ps1
echo       - Linux:   ./agents/linux_agent.sh
echo       - macOS:   ./agents/mac_agent.sh
echo       - Python:  python agents\python_agent.py
echo.
echo [*] For remote testing, modify SERVER_URL in agent scripts to your server's IP
echo ══════════════════════════════════════════════════════════════
echo.
pause 