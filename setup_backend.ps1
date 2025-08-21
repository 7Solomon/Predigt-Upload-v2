# This script sets up the Python virtual environment for the backend.
# It assumes it is located inside the 'backend' directory.

# --- Configuration ---
# Get the directory where the script itself is located.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$backendDir = Join-Path -Path $ScriptDir -ChildPath "backend"
$VenvDir = Join-Path -Path $backendDir -ChildPath "venv"
$RequirementsFile = Join-Path -Path $backendDir -ChildPath "requirements.txt"

# --- Main Logic ---
Write-Host "Starting backend setup..." -ForegroundColor Green

# 1. Check for Python 3
Write-Host "Checking for Python 3..."
# Find a suitable Python executable, ignoring the Windows Store alias
$pythonExecutables = Get-Command python*, python -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -notlike "*\WindowsApps\python*.exe" }

if ($null -eq $pythonExecutables) {
    Write-Host "ERROR: No suitable Python 3 installation found in your PATH." -ForegroundColor Red
    Write-Host "Please install Python 3 or ensure its location is in the system's PATH environment variable."
    exit 1
}

# Select the first valid Python executable found
$pythonExecutable = $pythonExecutables[0]
Write-Host "Found Python at: $($pythonExecutable.Source)"

# 2. Create Virtual Environment if it doesn't exist
if (-not (Test-Path $VenvDir)) {
    Write-Host "Creating Python virtual environment in '$VenvDir'..."
    & $pythonExecutable.Source -m venv $VenvDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to create virtual environment." -ForegroundColor Red
        exit 1
    }
    Write-Host "Virtual environment created successfully." -ForegroundColor Green
} else {
    Write-Host "Virtual environment already exists. Skipping creation."
}

# 3. Install dependencies
Write-Host "Installing dependencies from '$RequirementsFile'..."
$PipPath = Join-Path -Path $VenvDir -ChildPath "Scripts\pip.exe"
& $PipPath install -r $RequirementsFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to install dependencies." -ForegroundColor Red
    exit 1
}

Write-Host "Backend setup completed successfully!" -ForegroundColor Green
Read-Host "Press Enter to exit"
