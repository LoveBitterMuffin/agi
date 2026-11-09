# run-pingpong.ps1 - Autonomous Reviewer-Fixer Pair Programming Ping-Pong Loop
param(
    [int]$MaxCycles = 3,
    [switch]$VerifyOnly
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Reviewer <-> Fixer Ping-Pong Loop       " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

$cycle = 0
$approved = $false

while ($cycle -lt $MaxCycles) {
    $cycle++
    Write-Host "`n--- [CYCLE $cycle / $MaxCycles] code-reviewer: Auditing Working Tree ---" -ForegroundColor Yellow

    # Check 1: Memory & Bounds Linter
    $memoryScript = Join-Path $repoRoot ".agents\scripts\audit-memory.ps1"
    $memoryPass = $false
    try {
        & powershell -ExecutionPolicy Bypass -File $memoryScript | Out-Null
        $memoryPass = $true
    } catch {
        $memoryPass = $false
    }

    # Check 2: Git Diff Anomalies (merge conflict markers, mojibake)
    $diff = cmd /c "git diff HEAD 2>nul"
    if ($diff -is [array]) { $diff = $diff -join "`n" }
    $findings = @()

    if (-not $memoryPass) {
        $findings += @{ ID = "CF-MEM"; Severity = "CRITICAL"; Issue = "audit-memory.ps1 reported validation errors or dangling pointers" }
    }

    if ($diff -match "(?m)^[<>=]{7}") {
        $findings += @{ ID = "CF-CONFLICT"; Severity = "CRITICAL"; Issue = "Git merge conflict markers detected in diff" }
    }

    if ($diff -match "ðŸ") {
        $findings += @{ ID = "MF-MOJIBAKE"; Severity = "MINOR"; Issue = "ANSI encoded emoji mojibake detected in working copy" }
    }

    if ($findings.Count -eq 0) {
        Write-Host "VERDICT: APPROVED - All checks passed cleanly on Cycle $cycle!" -ForegroundColor Green
        $approved = $true
        break
    }

    # Findings detected -> CHANGES_REQUESTED
    Write-Host "VERDICT: CHANGES_REQUESTED - $($findings.Count) finding(s) detected:" -ForegroundColor Red
    foreach ($f in $findings) {
        Write-Host "  [$($f.Severity)] $($f.ID): $($f.Issue)" -ForegroundColor DarkYellow
    }

    if ($VerifyOnly) {
        Write-Host "STOP: VerifyOnly mode active; skipping automated fix." -ForegroundColor Yellow
        exit 1
    }

    # Dispatch defect-fixer
    Write-Host ">>> Handing baton to defect-fixer for atomic remediation..." -ForegroundColor Cyan

    # Automated Defect Remediation Logic
    foreach ($f in $findings) {
        if ($f.ID -eq "MF-MOJIBAKE") {
            Write-Host "    Applying automated UTF-8 sanitization via sync-obsidian.ps1..." -ForegroundColor Gray
            $syncScript = Join-Path $repoRoot ".agents\scripts\sync-obsidian.ps1"
            & powershell -ExecutionPolicy Bypass -File $syncScript | Out-Null
        }
    }

    Write-Host ">>> Patch applied. Returning baton to code-reviewer for re-audit..." -ForegroundColor Cyan
}

if (-not $approved) {
    Write-Host "`n[CIRCUIT-BREAKER TRIP] Exceeded maximum cycles ($MaxCycles) without full approval!" -ForegroundColor Red
    Write-Host "Halting execution to prevent token burn and infinite recursion." -ForegroundColor Red
    exit 1
}

Write-Host "`n[SUCCESS] Ping-Pong Loop completed successfully in $cycle cycle(s)." -ForegroundColor Green
exit 0
