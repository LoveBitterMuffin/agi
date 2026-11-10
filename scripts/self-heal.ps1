# self-heal.ps1 - Autonomous Memory & Workspace Repair Engine
param(
    [switch]$RepairMemory,
    [switch]$RepairPointers,
    [switch]$CleanLogs,
    [switch]$All,
    [int]$LogRetentionHours = 48,
    [string]$RootDir = ""
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

if ($RootDir) {
    $repoRoot = [System.IO.Path]::GetFullPath($RootDir)
} else {
    $cwd = (Get-Location).ProviderPath
    $gitTop = (git -C $cwd rev-parse --show-toplevel 2>$null)
    $homeNorm = [System.IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
    $cwdNorm = [System.IO.Path]::GetFullPath($cwd).TrimEnd('\', '/')
    $repoRoot = if ($gitTop -and ([System.IO.Path]::GetFullPath($gitTop).TrimEnd('\', '/') -ne $homeNorm -or $cwdNorm -eq $homeNorm)) { $gitTop } else { $cwd }
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  AntiGravity Autonomous Self-Healing     " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$repairedCount = 0
$doAll = $All -or (-not ($RepairMemory -or $RepairPointers -or $CleanLogs))

# 1. Synchronize Chapter SemVer to Index.md (supports both 4-col CH-NNN and [file.md] link rows)
if ($doAll -or $RepairMemory) {
    $indexPath = Join-Path $repoRoot "memory\Index.md"
    $chaptersDir = Join-Path $repoRoot "memory\wiki\chapters"
    if ((Test-Path $indexPath) -and (Test-Path $chaptersDir)) {
        $indexRaw = Get-Content $indexPath -Raw -Encoding UTF8
        $newline = if ($indexRaw -match "\r\n") { "`r`n" } else { "`n" }
        $indexLines = $indexRaw -split "\r?\n", -1
        $indexModified = $false
        $chapters = @(Get-ChildItem -Path $chaptersDir -Filter "*.md" -File)

        foreach ($ch in $chapters) {
            $chContent = Get-Content $ch.FullName -Raw -Encoding UTF8
            if (-not ($chContent -match '(?ms)^---\s*\r?\n(.*?)\r?\n---')) { continue }
            $fm = $matches[1]
            if (-not ($fm -match '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)')) { continue }
            $actualVer = $matches[1]
            $chId = if ($fm -match '(?m)^chapter_id:\s*(CH-[0-9]+)') { $matches[1] } else { "" }

            for ($i = 0; $i -lt $indexLines.Count; $i++) {
                $line = $indexLines[$i]
                if ($line -notmatch '^\s*\|') { continue }
                $matchesId = ($chId -and ($line -match ('\|\s*`?' + [regex]::Escape($chId) + '`?\s*\|')))
                $matchesFile = ($line -match ('\[' + [regex]::Escape($ch.Name) + '\]'))
                if (-not ($matchesId -or $matchesFile)) { continue }

                $verCellPattern = '(\|\s*`?)([0-9]+\.[0-9]+\.[0-9]+)(`?\s*\|)'
                if ($line -match $verCellPattern) {
                    $matchedVer = $matches[2]
                    if ($matchedVer -ne $actualVer) {
                        $indexLines[$i] = [regex]::Replace($line, $verCellPattern, "`${1}$actualVer`${3}", 1)
                        Write-Host "[HEAL] Updated $($ch.Name) in Index.md -> $actualVer (was $matchedVer)" -ForegroundColor Green
                        $indexModified = $true
                        $repairedCount++
                    }
                }
            }
        }
        if ($indexModified) {
            [System.IO.File]::WriteAllText($indexPath, ($indexLines -join $newline), $utf8NoBom)
        }
    }
}

# 2. Repair Out-of-Bound Lossless Pointers in Chapters
if ($doAll -or $RepairPointers) {
    $vaultDir = Join-Path $repoRoot "memory\raw\vault"
    $chaptersDir = Join-Path $repoRoot "memory\wiki\chapters"
    if ((Test-Path $vaultDir) -and (Test-Path $chaptersDir)) {
        $chapters = @(Get-ChildItem -Path $chaptersDir -Filter "*.md" -File)
        foreach ($ch in $chapters) {
            $chContent = Get-Content $ch.FullName -Raw -Encoding UTF8
            $modified = $false
            $pointerPattern = '(RAW-(?:SPEC-)?[0-9]{4}-[0-9]{3}(?:_[a-zA-Z0-9_\-\.]+?)?\.md).*?lines\s+([0-9]+)-([0-9]+)'
            $ptrMatches = [regex]::Matches($chContent, $pointerPattern)
            foreach ($m in $ptrMatches) {
                $targetRaw = $m.Groups[1].Value
                $startL = [int]$m.Groups[2].Value
                $endL = [int]$m.Groups[3].Value
                $rawPath = Join-Path $vaultDir $targetRaw
                if (Test-Path $rawPath) {
                    $totalLines = @(Get-Content $rawPath -Encoding UTF8).Count
                    if ($totalLines -gt 0 -and $endL -gt $totalLines) {
                        $newEndL = $totalLines
                        $newStartL = [Math]::Min($startL, $newEndL)
                        $oldSub = $m.Value
                        $newSub = $oldSub -replace "lines\s+[0-9]+-[0-9]+", "lines $newStartL-$newEndL"
                        $chContent = $chContent.Replace($oldSub, $newSub)
                        Write-Host "[HEAL] Clamped pointer in $($ch.Name) -> $targetRaw lines $newStartL-$newEndL" -ForegroundColor Yellow
                        $modified = $true
                        $repairedCount++
                    }
                }
            }
            if ($modified) {
                [System.IO.File]::WriteAllText($ch.FullName, $chContent, $utf8NoBom)
            }
        }
    }
}

# 3. Clean Stale Scratch Logs Older than LogRetentionHours (default 48h)
if ($doAll -or $CleanLogs) {
    $logsDir = Join-Path $repoRoot "scratch\logs"
    if (Test-Path $logsDir) {
        $staleTime = (Get-Date).AddHours(-$LogRetentionHours)
        $staleLogs = @(Get-ChildItem -Path $logsDir -Filter "*.log" -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $staleTime })
        foreach ($log in $staleLogs) {
            Remove-Item $log.FullName -Force -ErrorAction SilentlyContinue
            $repairedCount++
        }
        if ($staleLogs.Count -gt 0) {
            Write-Host "[HEAL] Purged $($staleLogs.Count) stale logs from scratch\logs\" -ForegroundColor DarkGray
        }
    }
}

Write-Host "Self-Healing complete: $repairedCount item(s) repaired or normalized." -ForegroundColor Green
exit 0
