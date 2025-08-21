# This script finds and stops the FastAPI backend server.

$Port = 8000
$ProcessPattern = "*uvicorn*main:app*" # A pattern to identify the backend process command line

Write-Host "Attempting to stop the backend server..."

# We use Get-CimInstance to find processes whose command line matches our server signature.
# This is more reliable than checking ports across different user sessions.
$processes = Get-CimInstance Win32_Process -Filter "name = 'python.exe' or name = 'uvicorn.exe'" | Where-Object { $_.CommandLine -like $ProcessPattern }

if ($processes) {
    foreach ($process in $processes) {
        $ProcessId = $process.ProcessId
        Write-Host "Found backend process with name '$($process.Name)' and PID $ProcessId. Stopping it..." -ForegroundColor Yellow
        try {
            Stop-Process -Id $ProcessId -Force -ErrorAction Stop
            Write-Host "Process $ProcessId stopped successfully." -ForegroundColor Green
        } catch {
            Write-Host "Failed to stop process $ProcessId. It might have already been terminated." -ForegroundColor Red
        }
    }
} else {
    Write-Host "No running backend server process found. It is likely already stopped." -ForegroundColor Cyan
}

exit 0
