# get-memory-brief.ps1 - Fast Context Extraction from AntiGravity Two-Layer Memory
param(
    [string]$Query = "",
    [string]$RootDir = ".",
    [switch]$Init
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$memoryDir = Join-Path $RootDir "memory"
$logsDir = Join-Path $memoryDir "logs"
$wikiDir = Join-Path $memoryDir "wiki\chapters"
$vaultDir = Join-Path $memoryDir "raw\vault"
$inboxDir = Join-Path $memoryDir "raw\inbox"
$indexPath = Join-Path $memoryDir "Index.md"
$sprintPath = Join-Path $logsDir "ActiveSprintLog.md"
$learningsPath = Join-Path $wikiDir "099_learnings.md"

# 1. Initialize Scaffold if missing or requested
if ($Init -or (-not (Test-Path $memoryDir))) {
    Write-Host "Initializing AntiGravity Memory Architecture in $RootDir/memory..." -ForegroundColor Cyan
    @($logsDir, $wikiDir, $vaultDir, $inboxDir) | ForEach-Object {
        if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
    }

    if (-not (Test-Path (Join-Path $vaultDir ".gitkeep"))) {
        Set-Content -Path (Join-Path $vaultDir ".gitkeep") -Value "" -Encoding utf8
    }
    if (-not (Test-Path (Join-Path $inboxDir ".gitkeep"))) {
        Set-Content -Path (Join-Path $inboxDir ".gitkeep") -Value "" -Encoding utf8
    }

    if (-not (Test-Path $sprintPath)) {
        $initialSprint = @"
# Active Sprint Log

## Current Sprint
- **Status:** Active
- **Goal:** Project Development & Architecture Alignment
- **Active Tasks:**
  - [x] Initial Scaffolding & Verification
  - [ ] Memory-Guided Feature Development

## Recent Decisions
- Adopted Antigravity Two-Layer Memory & Docs-as-Code pipeline.
- Established strict micro-modularity and Gate 0 user alignment.
"@
        Set-Content -Path $sprintPath -Value $initialSprint -Encoding utf8
    }

    if (-not (Test-Path (Join-Path $logsDir "CHANGELOG.md"))) {
        $initialChangelog = @"
# Changelog

## [0.1.0] - $(Get-Date -Format 'yyyy-MM-dd')
### Added
- Initial project scaffolding with AntiGravity Docs-as-Code memory.
"@
        Set-Content -Path (Join-Path $logsDir "CHANGELOG.md") -Value $initialChangelog -Encoding utf8
    }

    if (-not (Test-Path $indexPath)) {
        $initialIndex = @"
# AntiGravity Memory Index

| Chapter | Domain / Topic | Status | Version |
| :--- | :--- | :--- | :--- |
| [000_overview.md](wiki/chapters/000_overview.md) | High-level system overview & contracts | active | 1.0.0 |
| [099_learnings.md](wiki/chapters/099_learnings.md) | Continuous learnings & architectural pitfalls | active | 1.0.0 |
"@
        Set-Content -Path $indexPath -Value $initialIndex -Encoding utf8
    }

    if (-not (Test-Path (Join-Path $wikiDir "000_overview.md"))) {
        $initialOverview = @"
---
version: 1.0.0
status: active
---
# 000: System Overview

## System Identity & Core Contracts
Primary workspace architecture, runtime invariants, and tech stack boundaries.
"@
        Set-Content -Path (Join-Path $wikiDir "000_overview.md") -Value $initialOverview -Encoding utf8
    }

    if (-not (Test-Path $learningsPath)) {
        $initialLearnings = @"
---
version: 1.0.0
status: active
---
# 099: System Learnings & Known Pitfalls

## Architectural Invariants
1. Do not accumulate tool calls in main thread; delegate tasks modifying >=2 files to subagents.
2. Always execute Gate 0 ask_question before drafting specifications or coding.
"@
        Set-Content -Path $learningsPath -Value $initialLearnings -Encoding utf8
    }
}

# 2. Extract High-Density Context Brief
$brief = [System.Collections.Generic.List[string]]::new()
$brief.Add("# AntiGravity Active Memory Brief")
$brief.Add("> Auto-extracted for immediate working context (Zero Bloat)")

# 2.1 Sprint State (clamp to max 15 lines)
if (Test-Path $sprintPath) {
    $brief.Add("`n## 1. Active Sprint & Decisions")
    $sprintLines = Get-Content $sprintPath -Encoding utf8
    $extract = @()
    $capture = $false
    foreach ($line in $sprintLines) {
        if ($line -match '^## ') { $capture = $true }
        if ($capture) {
            $extract += $line
            if ($extract.Count -ge 14) { break }
        }
    }
    if ($extract.Count -gt 0) {
        $brief.Add(($extract -join "`n"))
    } else {
        $brief.Add(($sprintLines | Select-Object -First 10) -join "`n")
    }
}

# 2.2 Domain Chapters from Index.md matching Query
if (Test-Path $indexPath) {
    $brief.Add("`n## 2. Relevant Memory Chapters")
    $indexLines = Get-Content $indexPath -Encoding utf8
    $matchedChapters = @()
    $keywords = if ($Query) { $Query.ToLower().Split(" ,;`t", [System.StringSplitOptions]::RemoveEmptyEntries) } else { @() }

    foreach ($line in $indexLines) {
        if ($line -match '\[(.*?)\]\((.*?)\)') {
            $chapFile = $matches[1]
            $chapPath = $matches[2]
            $isMatch = $false

            if ($keywords.Count -eq 0) {
                $isMatch = $true
            } else {
                foreach ($kw in $keywords) {
                    if ($line.ToLower().Contains($kw) -or $chapFile.ToLower().Contains($kw)) {
                        $isMatch = $true
                        break
                    }
                }
            }

            if ($isMatch) {
                $matchedChapters += @{ File = $chapFile; Path = $chapPath; Line = $line }
            }
        }
    }

    if ($matchedChapters.Count -eq 0) {
        $brief.Add("- No specific chapters matched query '$Query'. Refer to memory/Index.md.")
    } else {
        foreach ($mc in ($matchedChapters | Select-Object -First 5)) {
            $brief.Add("- $($mc.Line)")
            $fullChapPath = Join-Path $memoryDir $mc.Path
            if (Test-Path $fullChapPath) {
                $cLines = Get-Content $fullChapPath -Encoding utf8
                $bodyLines = @()
                $inFm = $false
                foreach ($cl in $cLines) {
                    if ($cl -match '^---') { $inFm = -not $inFm; continue }
                    if (-not $inFm -and $cl.Trim().Length -gt 0) {
                        $bodyLines += "    > " + $cl
                        if ($bodyLines.Count -ge 4) { break }
                    }
                }
                if ($bodyLines.Count -gt 0) {
                    $brief.Add(($bodyLines -join "`n"))
                }
            }
        }
    }
}

# 2.3 Pitfalls from 099_learnings.md
if (Test-Path $learningsPath) {
    $brief.Add("`n## 3. Top Architectural Pitfalls (Learnings)")
    $learnLines = Get-Content $learningsPath -Encoding utf8
    $learningBullets = @()
    foreach ($ll in $learnLines) {
        if ($ll -match '^[0-9]+\.\s+' -or $ll -match '^\-\s+\*\*') {
            $learningBullets += $ll
            if ($learningBullets.Count -ge 5) { break }
        }
    }
    if ($learningBullets.Count -gt 0) {
        $brief.Add(($learningBullets -join "`n"))
    }
}

$result = $brief -join "`n"
Write-Output $result
