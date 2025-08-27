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

# 2. Check if virtual environment exists and is complete
$PipPath = Join-Path -Path $VenvDir -ChildPath "Scripts\pip.exe"
$PythonVenvPath = Join-Path -Path $VenvDir -ChildPath "Scripts\python.exe"

if ((Test-Path $VenvDir) -and (Test-Path $PipPath) -and (Test-Path $PythonVenvPath)) {
    Write-Host "Virtual environment already exists and appears complete. Skipping creation."
} else {
    if (Test-Path $VenvDir) {
        Write-Host "Incomplete virtual environment detected. Removing and recreating..." -ForegroundColor Yellow
        Remove-Item -Path $VenvDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "Creating Python virtual environment in '$VenvDir'..."
    & $pythonExecutable.Source -m venv $VenvDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to create virtual environment." -ForegroundColor Red
        exit 1
    }
    Write-Host "Virtual environment created successfully." -ForegroundColor Green
}

# 3. Verify pip exists before trying to use it
if (-not (Test-Path $PipPath)) {
    Write-Host "ERROR: pip.exe not found at '$PipPath'. Virtual environment may be corrupted." -ForegroundColor Red
    exit 1
}

# 4. Verify requirements file exists
if (-not (Test-Path $RequirementsFile)) {
    Write-Host "ERROR: Requirements file not found at '$RequirementsFile'" -ForegroundColor Red
    exit 1
}

# 5. Install dependencies
Write-Host "Installing dependencies from '$RequirementsFile'..."
& $PipPath install -r $RequirementsFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to install dependencies." -ForegroundColor Red
    exit 1
}

# 6. Create log directory if it doesn't exist
$LogDir = Join-Path -Path $backendDir -ChildPath "log"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force
    Write-Host "Created log directory: $LogDir" -ForegroundColor Green
}

# 7. Verify uvicorn is installed
$UvicornPath = Join-Path -Path $VenvDir -ChildPath "Scripts\uvicorn.exe"
if (Test-Path $UvicornPath) {
    Write-Host "Backend setup completed successfully!" -ForegroundColor Green
    Write-Host "Uvicorn found at: $UvicornPath" -ForegroundColor Green
} else {
    Write-Host "WARNING: uvicorn.exe not found. Backend may not start properly." -ForegroundColor Yellow
}

# Don't wait for input during automated installation or when called from wrapper
if (($env:INNO_SETUP_INSTALL -eq $null) -and ($env:AUTOMATED_INSTALL -eq $null)) {
    Read-Host "Press Enter to exit"
}

exit 0