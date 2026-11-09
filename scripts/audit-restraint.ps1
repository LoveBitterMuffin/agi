# audit-restraint.ps1 - Ponytail Ladder of Restraint & Anti-Bloat Linter
param(
    [int]$MaxNewFiles = 5,
    [switch]$Strict
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Ponytail Ladder of Restraint Linter     " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

# 1. Inspect Working Tree Statistics
$diffLines = cmd /c "git diff HEAD 2>nul"
if ($diffLines -is [string]) { $diffLines = @($diffLines) }
if (-not $diffLines) { $diffLines = @() }

$added = 0
$deleted = 0
foreach ($line in $diffLines) {
    if ($line -match "^\+[^\+]") { $added++ }
    elseif ($line -match "^\-[^\-]") { $deleted++ }
}

$untracked = cmd /c "git status --porcelain 2>nul"
$newFilesCount = 0
if ($untracked) {
    $newFilesCount = @($untracked | Where-Object { $_ -match "^\?\?" -or $_ -match "^A" }).Count
}

Write-Host "Working Tree Metrics:" -ForegroundColor White
Write-Host "  Lines Added:   +$added" -ForegroundColor Green
Write-Host "  Lines Deleted: -$deleted" -ForegroundColor Red
Write-Host "  New Files:     $newFilesCount (Threshold: $MaxNewFiles)" -ForegroundColor $(if ($newFilesCount -le $MaxNewFiles) { "Cyan" } else { "Yellow" })

# 2. Check 7-Rung Ladder Violations
$warnings = @()

# Rung 1 & 2: Gratuitous Helper / Factory abstractions
$boilerplateMatches = @($diffLines | Where-Object { $_ -match "class\s+[a-zA-Z0-9]+(?:Helper|Factory|Wrapper|Manager)\b" })
if ($boilerplateMatches.Count -gt 0) {
    $warnings += "Rung 2/6 Violation: Detected $($boilerplateMatches.Count) boilerplate Helper/Factory class(es). Verify if standard library or clean functions suffice."
}

# Rung 3 & 5: Dependency Bloat
$depMatches = @($diffLines | Where-Object { $_ -match "(?i)(?:npm\s+install|pip\s+install|Install-Module|gem\s+install)" })
if ($depMatches.Count -gt 0) {
    $warnings += "Rung 5 Warning: Detected third-party package installation commands. Verify if host platform/stdlib can solve this natively."
}

# 3. Overall Restraint Assessment
Write-Host "------------------------------------------" -ForegroundColor DarkGray
if ($warnings.Count -eq 0) {
    Write-Host "[PASS] Ponytail Restraint Enforced. Zero gratuitous boilerplate detected." -ForegroundColor Green
    exit 0
} else {
    foreach ($w in $warnings) {
        Write-Host "[WARN] $w" -ForegroundColor Yellow
    }
    if ($Strict) {
        Write-Host "[FAIL] Strict mode active: Restraint audit failed." -ForegroundColor Red
        exit 1
    } else {
        Write-Host "[PASS with Warnings] Advisory warnings noted. Restraint audit passed." -ForegroundColor Yellow
        exit 0
    }
}
