# audit-code.ps1 - Micro-Modularity & Anti-Slop Code Standards Linter
param(
    [int]$MaxFileLineThreshold = 150,
    [switch]$Strict,
    [switch]$All
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Micro-Modularity & Anti-Slop Linter     " -ForegroundColor Cyan
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

$candidateRoots = @("src", "handwriting_system/src", "app", "lib")
$detectedRoots = @($candidateRoots | Where-Object { Test-Path (Join-Path $repoRoot $_) })
$srcRegexFwd = '^(?:src|handwriting_system/src|app|lib)/'
$srcRegexAny = '^(?:src|handwriting_system[\\/]src|app|lib)[\\/]'

$failures = @()
$warnings = @()

# 1. Inspect Working Tree Diff (safe on unborn HEAD and non-git workspaces)
$hasHead = $false
$diffLines = @()
$porcelainLines = @()
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
    $porcelainLines = @(git -C $repoRoot -c core.quotepath=false status --porcelain 2>$null)
    $ErrorActionPreference = $prevEap
}

$untrackedFiles = @()
$modifiedFiles = @()
foreach ($entry in $porcelainLines) {
    if ($entry -match '^([ MADRCU?!]{2})\s+(.+)$') {
        $xy = $matches[1]
        $p = $matches[2].Trim().Trim('"')
        if ($p -match ' -> (.+)$') { $p = $matches[1].Trim().Trim('"') }
        if ($xy -match '^\?\?|^A') {
            $untrackedFiles += $p
        } elseif ($xy -match 'M') {
            $modifiedFiles += $p
        }
    }
}

# 2. Check Newly Added Files for Line Count (Hard 150-Line Bound)
$newSourceFiles = @($untrackedFiles | Where-Object {
    $_ -match $srcRegexAny -and $_ -match '\.(?:ts|js|py|vue|mjs)$' -and $_ -notmatch '[\\/]dist[\\/]'
})

foreach ($relPath in $newSourceFiles) {
    $fullPath = Join-Path $repoRoot $relPath
    if (Test-Path $fullPath) {
        $lineCount = @(Get-Content $fullPath -Encoding UTF8).Count
        if ($lineCount -gt $MaxFileLineThreshold) {
            $failures += "Micro-Modularity Violation: New file '$relPath' has $lineCount lines (Hard limit: $MaxFileLineThreshold lines)."
        } elseif ($lineCount -gt 100) {
            $warnings += "Advisory Warning: New file '$relPath' has $lineCount lines (Approaching limit of $MaxFileLineThreshold lines)."
        }
    }
}

# 2b. Legacy Ratchet Check on Modified Tracked Source Files
if ($hasHead) {
    $modSourceFiles = @($modifiedFiles | Where-Object {
        $_ -match $srcRegexAny -and $_ -match '\.(?:ts|js|py|vue|mjs)$' -and $_ -notmatch '[\\/]dist[\\/]'
    })
    foreach ($relPath in $modSourceFiles) {
        $fullPath = Join-Path $repoRoot $relPath
        if (Test-Path $fullPath) {
            $currCount = @(Get-Content $fullPath -Encoding UTF8).Count
            $gitRel = $relPath.Replace("\", "/")
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            $headContent = @(git -C $repoRoot show "HEAD:$gitRel" 2>$null)
            $showOk = ($LASTEXITCODE -eq 0)
            $ErrorActionPreference = $prevEap
            if ($showOk) {
                $headCount = $headContent.Count
                if ($headCount -gt $MaxFileLineThreshold -and $currCount -gt $headCount) {
                    $failures += "Legacy Ratchet Violation: '$relPath' grew from $headCount to $currCount lines (limit: $MaxFileLineThreshold). Extract new logic to a micro-module."
                } elseif ($headCount -le $MaxFileLineThreshold -and $currCount -gt $MaxFileLineThreshold) {
                    $failures += "Micro-Modularity Violation: Modified file '$relPath' expanded past $MaxFileLineThreshold lines ($headCount -> $currCount)."
                }
            }
        }
    }
}

# 3. Check Diff Lines for Anti-Slop Violations (Added Lines only)
$ruSlop = [regex]::Unescape('\u0444\u0443\u043d\u043a\u0446\u0438\u044f \u0434\u043b\u044f|\u0432\u043e\u0437\u0432\u0440\u0430\u0449\u0430\u0435\u043c \u0440\u0435\u0437\u0443\u043b\u044c\u0442\u0430\u0442|\u0438\u043d\u0438\u0446\u0438\u0430\u043b\u0438\u0437\u0430\u0446\u0438\u044f \u043f\u0435\u0440\u0435\u043c\u0435\u043d\u043d|\u0446\u0438\u043a\u043b \u043f\u043e|\u0441\u043e\u0437\u0434\u0430\u0435\u043c \u044d\u043a\u0437\u0435\u043c\u043f\u043b\u044f\u0440|\u043e\u0431\u0440\u0430\u0431\u043e\u0442\u043a\u0430 \u043e\u0448\u0438\u0431\u043a\u0438')
$slopPattern = "(?i)\/\/\s*(?:function to|initialize variables|return the result|loop through|create instance|$ruSlop)\b"

$currentFile = ""
foreach ($line in $diffLines) {
    if ($line -match '^\+\+\+ b/(.*)$') {
        $currentFile = $matches[1]
        continue
    }

    if ($line -match '^\+([^\+].*)$' -and $currentFile -match $srcRegexFwd) {
        $addedContent = $matches[1]

        if ($addedContent -match 'catch\s*\([^)]*\)\s*\{\s*\}' -or
            $addedContent -match 'except\s*:\s*pass' -or
            $addedContent -match 'except\s+[a-zA-Z0-9_.]+\s*:\s*pass') {
            $failures += "Defensive Resilience Violation in '$currentFile': Empty catch/except block detected ('$($addedContent.Trim())')."
        }

        if ($addedContent -match '(?i)\/\/\s*(?:TODO|FIXME|HACK|XXX)\b' -or
            $addedContent -match '(?i)#\s*(?:TODO|FIXME|HACK|XXX)\b') {
            $warnings += "Anti-Slop Warning in '$currentFile': Speculative TODO/FIXME tag found. Track in formal SPEC-YYYY-NNN instead."
        }

        if ($addedContent -match $slopPattern) {
            $warnings += "Anti-Slop Warning in '$currentFile': Tautological AI comment slop detected ('$($addedContent.Trim())')."
        }

        if ($addedContent -match '^\s*\/\/\s*(?:const|let|var|function|def|import|class)\s+[a-zA-Z0-9_]+') {
            $warnings += "Anti-Slop Warning in '$currentFile': Commented-out dead code detected ('$($addedContent.Trim())'). Use Git history."
        }
    }
}

# 4. If -All switch, report legacy debt summary across detected source roots
if ($All) {
    $scanRoots = if ($detectedRoots.Count -gt 0) { $detectedRoots } else { @("src") }
    Write-Host "`nScanning source files in ($($scanRoots -join ', ')) for legacy size distribution..." -ForegroundColor DarkGray
    $allSrc = @()
    foreach ($sr in $scanRoots) {
        $srPath = Join-Path $repoRoot $sr
        if (Test-Path $srPath) {
            $allSrc += @(Get-ChildItem $srPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                $_.Extension -in @(".ts", ".js", ".py", ".vue", ".mjs") -and $_.FullName -notmatch '[\\/](?:dist|node_modules|__pycache__)[\\/]'
            })
        }
    }

    $legacyOverLimit = 0
    foreach ($f in $allSrc) {
        $cnt = @(Get-Content $f.FullName -Encoding UTF8).Count
        if ($cnt -gt $MaxFileLineThreshold) {
            $legacyOverLimit++
        }
    }
    Write-Host "Total source files: $($allSrc.Count) | Legacy monoliths (>$MaxFileLineThreshold lines): $legacyOverLimit" -ForegroundColor Yellow
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
