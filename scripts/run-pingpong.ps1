# run-pingpong.ps1 - Autonomous Reviewer-Fixer Pair Programming Ping-Pong Loop
param(
    [int]$MaxCycles = 2,
    [switch]$VerifyOnly
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

if ($MaxCycles -gt 2) {
    Write-Host "[INFO] Clamping MaxCycles from $MaxCycles to protocol cap 2." -ForegroundColor DarkGray
    $MaxCycles = 2
} elseif ($MaxCycles -lt 1) {
    $MaxCycles = 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Reviewer <-> Fixer Ping-Pong Loop       " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$cwd = (Get-Location).ProviderPath
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$gitTop = (git -C $cwd rev-parse --show-toplevel 2>$null)
$ErrorActionPreference = $prevEap
$homeNorm = [System.IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
$cwdNorm = [System.IO.Path]::GetFullPath($cwd).TrimEnd('\', '/')
$isProjectGit = [bool]($gitTop -and ([System.IO.Path]::GetFullPath($gitTop).TrimEnd('\', '/') -ne $homeNorm -or $cwdNorm -eq $homeNorm))
$repoRoot = if ($isProjectGit) { $gitTop } else { $cwd }

$mojibakePattern = [regex]::Unescape('\u00f0\u0178')
$cycle = 0
$approved = $false

while ($cycle -lt $MaxCycles) {
    $cycle++
    Write-Host "`n--- [CYCLE $cycle / $MaxCycles] code-reviewer: Auditing Working Tree ---" -ForegroundColor Yellow

    # Check 1: Memory & Bounds Linter via PSScriptRoot
    $memoryScript = Join-Path $PSScriptRoot "audit-memory.ps1"
    $memoryPass = $false
    if (Test-Path $memoryScript) {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $memoryScript -RootDir $repoRoot | Out-Null
        $memoryPass = ($LASTEXITCODE -eq 0)
        $ErrorActionPreference = $prevEap
    }

    # Check 2: Git Diff Anomalies (merge conflict markers, mojibake) - unborn HEAD and non-git safe
    $diffLines = @()
    if ($isProjectGit) {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        git -C $repoRoot rev-parse --verify HEAD 2>$null | Out-Null
        $hasHead = ($LASTEXITCODE -eq 0)
        $diffLines = if ($hasHead) {
            @(git -C $repoRoot -c core.quotepath=false diff HEAD 2>$null)
        } else {
            @(git -C $repoRoot -c core.quotepath=false diff --cached 2>$null)
        }
        $ErrorActionPreference = $prevEap
    }
    $diff = $diffLines -join "`n"

    $findings = @()

    if (-not $memoryPass) {
        $findings += @{ ID = "CF-MEM"; Severity = "CRITICAL"; Issue = "audit-memory.ps1 reported validation errors or dangling pointers" }
    }

    if ($diff -match "(?m)^[<>=]{7}") {
        $findings += @{ ID = "CF-CONFLICT"; Severity = "CRITICAL"; Issue = "Git merge conflict markers detected in diff" }
    }

    if ($diff -match $mojibakePattern) {
        $findings += @{ ID = "MF-MOJIBAKE"; Severity = "MINOR"; Issue = "ANSI encoded emoji mojibake detected in working copy" }
    }

    if ($findings.Count -eq 0) {
        Write-Host "VERDICT: APPROVED - All checks passed cleanly on Cycle $cycle!" -ForegroundColor Green
        $approved = $true
        break
    }

    Write-Host "VERDICT: CHANGES_REQUESTED - $($findings.Count) finding(s) detected:" -ForegroundColor Red
    foreach ($f in $findings) {
        Write-Host "  [$($f.Severity)] $($f.ID): $($f.Issue)" -ForegroundColor DarkYellow
    }

    if ($VerifyOnly) {
        Write-Host "STOP: VerifyOnly mode active; skipping automated fix." -ForegroundColor Yellow
        exit 1
    }

    # Dispatch remediation only for supported automated repairs
    Write-Host ">>> Handing baton to defect-fixer for atomic remediation..." -ForegroundColor Cyan
    foreach ($f in $findings) {
        if ($f.ID -eq "CF-MEM") {
            $healScript = Join-Path $PSScriptRoot "self-heal.ps1"
            if (Test-Path $healScript) {
                $prevEap = $ErrorActionPreference
                $ErrorActionPreference = "Continue"
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $healScript -RepairMemory -RepairPointers -RootDir $repoRoot | Out-Null
                $healExit = $LASTEXITCODE
                $ErrorActionPreference = $prevEap
                Write-Host "    self-heal.ps1 exit code: $healExit" -ForegroundColor Gray
            }
        } else {
            Write-Host "    Manual/subagent debugger intervention required for $($f.ID)." -ForegroundColor Yellow
        }
    }

    Write-Host ">>> Returning baton to code-reviewer for re-audit..." -ForegroundColor Cyan
}

if (-not $approved) {
    Write-Host "`n[CIRCUIT-BREAKER TRIP] Exceeded maximum cycles ($MaxCycles) without full approval!" -ForegroundColor Red
    Write-Host "Halting execution to prevent token burn and infinite recursion." -ForegroundColor Red
    exit 1
}

Write-Host "`n[SUCCESS] Ping-Pong Loop completed successfully in $cycle cycle(s)." -ForegroundColor Green
exit 0
