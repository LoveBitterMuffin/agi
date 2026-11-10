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
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

$cwd = (Get-Location).ProviderPath
$gitTop = (git -C $cwd rev-parse --show-toplevel 2>$null)
$homeNorm = [System.IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
$cwdNorm = [System.IO.Path]::GetFullPath($cwd).TrimEnd('\', '/')
$repoRoot = if ($gitTop -and ([System.IO.Path]::GetFullPath($gitTop).TrimEnd('\', '/') -ne $homeNorm -or $cwdNorm -eq $homeNorm)) { $gitTop } else { $cwd }

# 1. Resolve Subagent Role & Profile (agents/ -> fallback subagents/, local -> plugin -> global)
$candidates = @(
    (Join-Path $repoRoot ".agents\agents\$SubagentName.md"),
    (Join-Path $repoRoot ".agents\subagents\$SubagentName.md"),
    (Join-Path $PSScriptRoot "..\agents\$SubagentName.md"),
    (Join-Path $PSScriptRoot "..\subagents\$SubagentName.md")
)

$subagentFile = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $subagentFile) {
    $globalMatch = Get-ChildItem -Path "$HOME\.gemini\config\plugins\*\agents\$SubagentName.md", "$HOME\.gemini\config\plugins\*\subagents\$SubagentName.md" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($globalMatch) {
        $subagentFile = $globalMatch.FullName
    }
}

$roleTitle = $SubagentName
$desc = "Specialized autonomous worker"
$isReadOnlyRole = $SubagentName -in @("research", "explorer-agent", "security-auditor", "code-archaeologist", "product-owner", "product-manager", "project-planner")

if ($subagentFile -and (Test-Path $subagentFile)) {
    $content = Get-Content $subagentFile -Raw -Encoding UTF8
    if ($content -match 'description:\s*(.*?)(?=\r?\n[a-zA-Z0-9_\-]+:|\r?\n---|\Z)') {
        $desc = ($matches[1] -replace '\s+', ' ').Trim()
    }
    if ($content -match '(?ms)tools:\s*\r?\n(.*?)(?=\r?\n[a-zA-Z0-9_\-]+:|\r?\n---|\Z)') {
        $toolBlock = $matches[1]
        if ($toolBlock -notmatch 'write_file|edit_file|run_command') {
            $isReadOnlyRole = $true
        }
    }
}

$nativeTypeName = if ($isReadOnlyRole -and -not $EnforceTDD) { "research" } else { "self" }
$shieldedPath = Join-Path $PSScriptRoot "run-shielded.ps1"

# 2. Build 4-Section Structured Prompt
$boundaries = @()
if ($TargetFiles.Count -gt 0) {
    $boundaries += "- Target file paths: $($TargetFiles -join ', ')"
} else {
    $boundaries += "- Target scope: Strictly scoped to files relevant to this task."
}
$boundaries += "- Context Hygiene: Ban on full file reads >250 lines; use range reading (read_file with StartLine/EndLine)."
$boundaries += "- Ponytail Restraint: 7-Rung Ladder evaluation before code generation; micro-modularity (<=150 lines/file, <=30 lines/function, nesting <=3); -40% to -50% code volume."
$boundaries += "- Terminal Isolation: Shield main context from large build or test console dumps."
$boundaries += "- Memory Working Set: Consult memory/Index.md or get-memory-brief.ps1 for invariants."

$actions = @()
$actions += "1. Inspect current state and requirements for: $TaskDescription."
$actions += "2. Evaluate Ponytail 7-Rung Ladder of Restraint (YAGNI -> Re-use -> Stdlib -> Platform -> Dependencies -> Minimal Expression -> Minimum Code)."
if ($EnforceTDD) {
    $actions += "3. Write machine-checked unit test in tests/ FIRST before implementing domain logic."
    $actions += "4. Implement minimum code satisfying the requirement adhering to micro-modularity (<=150 lines/file, <=30 lines/function)."
    $actions += "5. Run targeted test with shielded output ($shieldedPath)."
} else {
    $actions += "3. Execute surgical changes adhering to Rule 04 (micro-modularity <=150 lines, cognitive nesting <=3)."
    $actions += "4. Verify execution and ensure zero side effects or broken contracts."
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
${roleTitle} (TypeName: ${nativeTypeName}): $desc
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
        TypeName = $nativeTypeName
        Role = $roleTitle
        Prompt = $prompt
    } | ConvertTo-Json -Depth 3
} else {
    Write-Output $prompt
}
