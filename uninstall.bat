@echo off
echo Looking for WSL...

REM Use Ubuntu explicitly (most common distro with full bash support)
wsl -d Ubuntu -e echo "Ubuntu found" >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Ubuntu WSL distribution not found.
    echo.
    echo Available distributions:
    wsl -l -v
    pause
    exit /b 1
)

echo Using Ubuntu WSL distribution...
echo.

wsl -d Ubuntu --cd "%~dp0" -e bash ./uninstall.sh

echo.
echo Cleanup finished.
pause
