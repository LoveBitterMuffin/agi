# generate-prompt.ps1 - Meta-Prompt Synthesizer and Subagent Dispatch Architect
param(
    [Parameter(Mandatory=$true)]
    [string]$SubagentName,

    [Parameter(Mandatory=$true)]
    [string]$TaskDescription,

    [string[]]$TargetFiles = @(),
    [switch]$EnforceTDD,
    [switch]$JsonOutput
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

# 1. Resolve Subagent Role & Profile (Local -> Global Plugins)
$subagentDir = Join-Path $repoRoot ".agents\subagents"
$subagentFile = Join-Path $subagentDir "$SubagentName.md"

$roleTitle = $SubagentName
$desc = "Specialized autonomous worker"

if (-not (Test-Path $subagentFile)) {
    $globalMatch = Get-ChildItem -Path "$HOME\.gemini\config\plugins\*\subagents\$SubagentName.md" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($globalMatch) {
        $subagentFile = $globalMatch.FullName
    }
}

if (Test-Path $subagentFile) {
    $content = Get-Content $subagentFile -Raw -Encoding utf8
    if ($content -match 'description:\s*(.*?)(?=\r?\n[a-zA-Z0-9_\-]+:|\r?\n---|\Z)') {
        $desc = ($matches[1] -replace '\s+', ' ').Trim()
    }
}

# 2. Build 4-Section Structured Prompt
$boundaries = @()
if ($TargetFiles.Count -gt 0) {
    $boundaries += "- Target file paths: $($TargetFiles -join ', ')"
} else {
    $boundaries += "- Target scope: Strictly scoped to files relevant to this task."
}
$boundaries += "- Context Hygiene: Ban on full file reads >250 lines; use range reading (read_file with StartLine/EndLine)."
$boundaries += "- Terminal Isolation: Shield main context from large build or test console dumps."
$boundaries += "- Memory Working Set: Consult memory/Index.md or get-memory-brief.ps1 for invariants."

$actions = @()
$actions += "1. Inspect current state and requirements for: $TaskDescription."
if ($EnforceTDD) {
    $actions += "2. Write machine-checked unit test in tests/ (Vitest/Jest) FIRST before implementing domain logic."
    $actions += "3. Implement minimum code satisfying the requirement adhering to micro-modularity (<=150 lines/file, <=30 lines/function)."
    $actions += "4. Run targeted test with shielded output (.agents/scripts/run-shielded.ps1)."
} else {
    $actions += "2. Execute surgical changes adhering to Rule 04 (micro-modularity <=150 lines, cognitive nesting <=3)."
    $actions += "3. Verify execution and ensure zero side effects or broken contracts."
}

$deliverable = @"
Return a concise summary (max 15 lines):
- Status: [SUCCESS / BLOCKED]
- Files Modified/Created: [List]
- Verification Proof: [Exit code & test run time]
- Memory & Doc Updates: [Wiki chapters touched if any]
"@

$prompt = @"
### 1. Role & Objective
${roleTitle}: $desc
Task Objective: $TaskDescription

### 2. Resource Boundaries
$($boundaries -join "`n")

### 3. Action Checklist
$($actions -join "`n")

### 4. Expected Deliverable
$deliverable
"@

if ($JsonOutput) {
    [PSCustomObject]@{
        Subagent = $SubagentName
        Role = $roleTitle
        Prompt = $prompt
    } | ConvertTo-Json -Depth 3
} else {
    Write-Output $prompt
}
