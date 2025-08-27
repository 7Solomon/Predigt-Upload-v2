@echo off
REM App wrapper that starts backend and main application

REM Get the directory where this script is located
set "APP_DIR=%~dp0"
set "BACKEND_DIR=%APP_DIR%backend"

echo DEBUG: App directory: %APP_DIR%
echo DEBUG: Backend directory: %BACKEND_DIR%
echo DEBUG: Checking if venv exists...

if exist "%BACKEND_DIR%\venv\Scripts\uvicorn.exe" (
    echo DEBUG: Virtual environment found
) else (
    echo DEBUG: Virtual environment NOT found
    echo DEBUG: Running setup script again...
    REM Set environment variable to prevent pause
    set "AUTOMATED_INSTALL=1"
    powershell.exe -ExecutionPolicy Bypass -Command "$env:AUTOMATED_INSTALL='1'; & '%APP_DIR%\setup_backend.ps1'"
)

REM Start the backend
echo Starting backend server...
powershell.exe -ExecutionPolicy Bypass -File "%BACKEND_DIR%\run_backend.ps1"

REM Wait a moment for backend to start
timeout /t 3 /nobreak >nul

REM Start the main application
echo Starting main application...
start "" "%APP_DIR%predigt_upload_v2.exe"

REM Wait for the main application to close
:wait_loop
timeout /t 2 /nobreak >nul
tasklist /fi "imagename eq predigt_upload_v2.exe" 2>nul | find /i "predigt_upload_v2.exe" >nul
if "%errorlevel%"=="0" goto wait_loop

REM Main app has closed, stop the backend
echo Main application closed. Stopping backend...
powershell.exe -ExecutionPolicy Bypass -File "%BACKEND_DIR%\stop_backend.ps1"

echo Cleanup complete.