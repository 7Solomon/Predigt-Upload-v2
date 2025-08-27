# This script runs the FastAPI backend server using the venv
$BackendDir = $PSScriptRoot
$LogFile = Join-Path (Join-Path $BackendDir "log") "backend.log"
$Port = 8000

# Check if a process is already using the port
$existingProcess = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($existingProcess) {
    Write-Host "Backend server is already running on port $Port." -ForegroundColor Green
    Write-Host "To view logs, run: Get-Content '$LogFile' -Wait -Tail 10"
    Write-Host "To stop the server, run: & '$PSScriptRoot\stop_backend.ps1'"
    exit 0
}

# --- Virtual Environment and Executable Paths ---
$UvicornExe = Join-Path $BackendDir "venv\Scripts\uvicorn.exe"

# Check if the virtual environment exists
if (-not (Test-Path $UvicornExe)) {
    Write-Host "ERROR: Virtual environment not found. Please run setup_backend.ps1 first." -ForegroundColor Red
    exit 1
}

# --- Start the Server in the Background ---
Write-Host "Starting FastAPI server in the background..." -ForegroundColor Cyan

# Prepare arguments for uvicorn
$arguments = "main:app", "--host", "127.0.0.1", "--port", "$Port"

# Use Start-Process to run the server in a new, hidden window
# and redirect all of its output to the log file.
Start-Process -FilePath $UvicornExe -ArgumentList $arguments -WorkingDirectory $BackendDir -WindowStyle Hidden -RedirectStandardOutput $LogFile -RedirectStandardError "${LogFile}.err"

# Give the server a moment to start up
Start-Sleep -Seconds 2

# Verify if the process started successfully
$newProcess = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($newProcess) {
    Write-Host "Backend server started successfully on port $Port." -ForegroundColor Green
    Write-Host "PID: $($newProcess.OwningProcess)"
    Write-Host "Logs are being written to: $LogFile"
    Write-Host "To view live logs, run: Get-Content '$LogFile' -Wait -Tail 10"
    Write-Host "To stop the server, run: & '$PSScriptRoot\stop_backend.ps1'"
} else {
    Write-Host "ERROR: The backend server failed to start. Check the log for details:" -ForegroundColor Red
    Write-Host "$LogFile"
    if (Test-Path $LogFile) {
        Get-Content $LogFile
    } else {
        Write-Host "Log file not found. The process might have failed to start." -ForegroundColor Red
    }
}

