# hook-pre-tool.ps1 - Antigravity PreToolUse Lifecycle Hook
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
        $cmd = if ($payload.toolCall -and $payload.toolCall.args) { $payload.toolCall.args.CommandLine } else { "N/A" }
        $logLine = "[$timestamp] [HOOK:PreToolUse] $($payload.toolCall.name): $cmd`n"
        [System.IO.File]::AppendAllText((Join-Path $logDir "hook_activity.log"), $logLine, $utf8NoBom)
    }
}

# Return valid JSON contract to allow tool execution
$response = @{
    decision = "allow"
}
$response | ConvertTo-Json -Compress
exit 0
