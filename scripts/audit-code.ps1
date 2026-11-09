# audit-code.ps1 - Micro-Modularity & Anti-Slop Code Standards Linter
param(
    [int]$MaxFileLineThreshold = 150,
    [switch]$Strict,
    [switch]$All
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Micro-Modularity & Anti-Slop Linter     " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

$failures = @()
$warnings = @()

# 1. Inspect Working Tree Diff
$diffLines = cmd /c "git diff HEAD 2>nul"
if ($diffLines -is [string]) { $diffLines = @($diffLines) }
if (-not $diffLines) { $diffLines = @() }

$untrackedOutput = cmd /c "git status --porcelain 2>nul"
$untrackedFiles = @()
if ($untrackedOutput) {
    if ($untrackedOutput -is [string]) { $untrackedOutput = @($untrackedOutput) }
    foreach ($entry in $untrackedOutput) {
        if ($entry -match '^(?:\?\?|A\s+)\s*(.*)$') {
            $untrackedFiles += $matches[1].Trim()
        }
    }
}

# 2. Check Newly Added Files for Line Count (Hard 150-Line Bound)
$newSourceFiles = @($untrackedFiles | Where-Object {
    $_ -match '^src[\\/]' -and $_ -match '\.(?:ts|js|py|vue|mjs)$' -and $_ -notmatch '[\\/]dist[\\/]'
})

foreach ($relPath in $newSourceFiles) {
    $fullPath = Join-Path $repoRoot $relPath
    if (Test-Path $fullPath) {
        $lineCount = (Get-Content $fullPath | Measure-Object -Line).Lines
        if ($lineCount -gt $MaxFileLineThreshold) {
            $failures += "Micro-Modularity Violation: New file '$relPath' has $lineCount lines (Hard limit: $MaxFileLineThreshold lines)."
        } elseif ($lineCount -gt 100) {
            $warnings += "Advisory Warning: New file '$relPath' has $lineCount lines (Approaching limit of $MaxFileLineThreshold lines)."
        }
    }
}

# 3. Check Diff Lines for Anti-Slop Violations (Added Lines only)
$currentFile = ""
$lineNum = 0

foreach ($line in $diffLines) {
    if ($line -match '^\+\+\+ b/(.*)$') {
        $currentFile = $matches[1]
        continue
    }

    # Only inspect added lines in source files
    if ($line -match '^\+([^\+].*)$' -and $currentFile -match '^src/') {
        $addedContent = $matches[1]

        # A. Empty catch/except blocks
        if ($addedContent -match 'catch\s*\([^)]*\)\s*\{\s*\}' -or
            $addedContent -match 'except\s*:\s*pass' -or
            $addedContent -match 'except\s+[a-zA-Z0-9_.]+\s*:\s*pass') {
            $failures += "Defensive Resilience Violation in '$currentFile': Empty catch/except block detected ('$($addedContent.Trim())')."
        }

        # B. Speculative Backlog in Code
        if ($addedContent -match '(?i)\/\/\s*(?:TODO|FIXME|HACK|XXX)\b' -or
            $addedContent -match '(?i)#\s*(?:TODO|FIXME|HACK|XXX)\b') {
            $warnings += "Anti-Slop Warning in '$currentFile': Speculative TODO/FIXME tag found. Track in formal SPEC-YYYY-NNN instead."
        }

        # C. Tautological AI Comment Slop
        if ($addedContent -match '(?i)\/\/\s*(?:function to|initialize variables|return the result|loop through|create instance|функция для|возвращаем результат|инициализация переменн|цикл по|создаем экземпляр|обработка ошибки)\b') {
            $warnings += "Anti-Slop Warning in '$currentFile': Tautological AI comment slop detected ('$($addedContent.Trim())')."
        }

        # D. Commented-out Dead Code
        if ($addedContent -match '^\s*\/\/\s*(?:const|let|var|function|def|import|class)\s+[a-zA-Z0-9_]+') {
            $warnings += "Anti-Slop Warning in '$currentFile': Commented-out dead code detected ('$($addedContent.Trim())'). Use Git history."
        }
    }
}

# 4. If -All switch, report legacy debt summary
if ($All) {
    Write-Host "`nScanning all source files in src/ for legacy size distribution..." -ForegroundColor DarkGray
    $allSrc = Get-ChildItem (Join-Path $repoRoot "src") -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Extension -in @(".ts", ".js", ".py", ".vue", ".mjs") -and $_.FullName -notmatch '[\\/]dist[\\/]'
    }

    $legacyOverLimit = 0
    foreach ($f in $allSrc) {
        $cnt = (Get-Content $f.FullName | Measure-Object -Line).Lines
        if ($cnt -gt $MaxFileLineThreshold) {
            $legacyOverLimit++
        }
    }
    Write-Host "Total source files: $($allSrc.Count) | Legacy monoliths (>150 lines): $legacyOverLimit" -ForegroundColor Yellow
    Write-Host "Ratchet Policy Active: Legacy files may not expand upon edit; new files strictly capped at $MaxFileLineThreshold lines." -ForegroundColor DarkGray
}

# 5. Output Summary & Verdict
Write-Host "------------------------------------------" -ForegroundColor DarkGray

if ($failures.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "[PASS] Micro-modularity and code hygiene verified. Zero violations." -ForegroundColor Green
    exit 0
}

if ($warnings.Count -gt 0) {
    foreach ($w in $warnings) {
        Write-Host "[WARN] $w" -ForegroundColor Yellow
    }
}

if ($failures.Count -gt 0) {
    foreach ($f in $failures) {
        Write-Host "[FAIL] $f" -ForegroundColor Red
    }
    Write-Host "`n[FATAL] Code standard audit failed with $($failures.Count) critical violation(s)." -ForegroundColor Red
    exit 1
}

if ($Strict -and $warnings.Count -gt 0) {
    Write-Host "`n[FAIL] Strict mode active: Warnings treated as fatal." -ForegroundColor Red
    exit 1
}

Write-Host "[PASS with Warnings] Advisory warnings noted. Code standard audit passed." -ForegroundColor Yellow
exit 0
