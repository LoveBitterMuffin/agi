# hook-stop.ps1 - Antigravity Stop Lifecycle Hook
$ErrorActionPreference = "SilentlyContinue"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

# Read JSON payload from stdin
$inputRaw = [Console]::In.ReadToEnd()
$payload = $null
if ($inputRaw) {
    try {
        $payload = $inputRaw | ConvertFrom-Json
    } catch {
        $payload = $null
    }
}

# Optional telemetry logging
if ($payload -and $payload.workspacePaths -and $payload.workspacePaths.Count -gt 0) {
    $ws = $payload.workspacePaths[0]
    $logDir = Join-Path $ws "scratch"
    if (Test-Path $logDir) {
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $reason = if ($payload.terminationReason) { $payload.terminationReason } else { "UNKNOWN" }
        $logLine = "[$timestamp] [HOOK:Stop] Terminated reason: $reason`n"
        [System.IO.File]::AppendAllText((Join-Path $logDir "hook_activity.log"), $logLine, $utf8NoBom)
    }
}

# Return valid JSON contract
$response = @{
    decision = "allow"
}
$response | ConvertTo-Json -Compress
exit 0
