# audit-memory.ps1 - Deterministic Memory Integrity Linter for AntiGravity Docs-as-Code

param(
    [string]$RootDir = "."
)

$ErrorActionPreference = "Stop"
$failures = 0
$warnings = 0

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  AntiGravity Memory Integrity Linter    " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$memoryDir = Join-Path $RootDir "memory"
$wikiDir = Join-Path $memoryDir "wiki\chapters"
$vaultDir = Join-Path $memoryDir "raw\vault"
$indexPath = Join-Path $memoryDir "Index.md"
$sprintLogPath = Join-Path $memoryDir "logs\ActiveSprintLog.md"

# 1. Verify Directory Hierarchy
if (-not (Test-Path $memoryDir)) {
    Write-Host "[FAIL] Missing memory directory: $memoryDir" -ForegroundColor Red
    exit 1
}

# 2. Check ActiveSprintLog line count (Threshold: 180 lines)
if (Test-Path $sprintLogPath) {
    $sprintLines = @(Get-Content $sprintLogPath).Count
    if ($sprintLines -gt 180) {
        Write-Host "[FAIL] ActiveSprintLog.md exceeds 180 lines ($sprintLines lines). Compaction required!" -ForegroundColor Red
        $failures++
    } elseif ($sprintLines -gt 150) {
        Write-Host "[WARN] ActiveSprintLog.md is approaching threshold ($sprintLines / 180 lines)." -ForegroundColor Yellow
        $warnings++
    } else {
        Write-Host "[PASS] ActiveSprintLog.md: $sprintLines lines (Threshold: 180)" -ForegroundColor Green
    }
} else {
    Write-Host "[FAIL] Missing ActiveSprintLog.md at $sprintLogPath" -ForegroundColor Red
    $failures++
}

# 3. Read Index.md content
$indexContent = ""
if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw
    Write-Host "[PASS] Index.md found and accessible." -ForegroundColor Green
} else {
    Write-Host "[FAIL] Missing Index.md at $indexPath" -ForegroundColor Red
    $failures++
}

# 4. Check Wiki Chapters and Lossless Line Pointers
$chapterFiles = Get-ChildItem -Path $wikiDir -Filter "*.md" -ErrorAction SilentlyContinue

if ($chapterFiles.Count -eq 0) {
    Write-Host "[WARN] No wiki chapters found in $wikiDir" -ForegroundColor Yellow
    $warnings++
} else {
    Write-Host "Auditing $($chapterFiles.Count) Wiki Chapter(s)..." -ForegroundColor Cyan
    foreach ($chapter in $chapterFiles) {
        $content = Get-Content $chapter.FullName -Raw
        $chapterName = $chapter.Name
        
        # Verify Registration in Index.md
        if ($indexContent -and ($indexContent -notmatch [regex]::Escape($chapterName))) {
            Write-Host "[FAIL] Chapter $chapterName is NOT registered in Index.md!" -ForegroundColor Red
            $failures++
        } else {
            Write-Host "[PASS] $chapterName is registered in Index.md" -ForegroundColor Green
        }

        # Check Frontmatter SemVer
        if ($content -match '(?ms)^---\s*\r?\n(.*?)\r?\n---') {
            $frontmatter = $matches[1]
            if ($frontmatter -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
                $ver = $matches[1]
                Write-Host "       Version: $ver" -ForegroundColor DarkGray
            } else {
                Write-Host "[FAIL] $chapterName is missing valid SemVer in YAML frontmatter!" -ForegroundColor Red
                $failures++
            }
        } else {
            Write-Host "[FAIL] $chapterName is missing YAML frontmatter header!" -ForegroundColor Red
            $failures++
        }

        # Find and Verify Line Pointers (pattern: "lines X-Y")
        $pointerMatches = [regex]::Matches($content, '(RAW-(?:SPEC-)?[0-9]{4}-[0-9]{3}_[a-zA-Z0-9_\-\.]+?\.md).*?lines\s+([0-9]+)-([0-9]+)')
        foreach ($match in $pointerMatches) {
            $targetRaw = $match.Groups[1].Value
            $startL = [int]$match.Groups[2].Value
            $endL = [int]$match.Groups[3].Value
            $rawPath = Join-Path $vaultDir $targetRaw

            if (-not (Test-Path $rawPath)) {
                Write-Host "[FAIL] Pointer references non-existent vault file: $targetRaw (in $chapterName)" -ForegroundColor Red
                $failures++
            } else {
                $rawLinesCount = @(Get-Content $rawPath).Count
                if ($startL -lt 1 -or $endL -lt $startL -or $endL -gt $rawLinesCount) {
                    Write-Host "[FAIL] Out-of-bounds pointer in $chapterName -> $targetRaw lines $startL-$endL (actual total lines: $rawLinesCount)" -ForegroundColor Red
                    $failures++
                } else {
                    Write-Host "[PASS] Valid lossless pointer: $targetRaw (lines $startL-$endL / total $rawLinesCount)" -ForegroundColor Green
                }
            }
        }
    }
}

# 5. Inbox Check
$inboxDir = Join-Path $memoryDir "raw\inbox"
$inboxFiles = Get-ChildItem -Path $inboxDir -Exclude ".gitkeep" -ErrorAction SilentlyContinue
if ($inboxFiles.Count -gt 0) {
    Write-Host "[WARN] Pending uningested files in inbox: $($inboxFiles.Count) file(s)" -ForegroundColor Yellow
    $warnings++
} else {
    Write-Host "[PASS] Raw inbox is clean (0 pending files)." -ForegroundColor Green
}

Write-Host "-----------------------------------------" -ForegroundColor Cyan
Write-Host "Audit Complete: $failures failure(s), $warnings warning(s)." -ForegroundColor $(if ($failures -eq 0) { "Green" } else { "Red" })

if ($failures -gt 0) {
    exit 1
}
exit 0
