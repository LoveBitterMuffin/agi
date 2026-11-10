# get-memory-brief.ps1 - Fast Context Extraction from AntiGravity Two-Layer Memory
param(
    [string]$Query = "",
    [string]$RootDir = ".",
    [switch]$Init
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, $script:utf8NoBom)
}

$memoryDir = Join-Path $RootDir "memory"
$logsDir = Join-Path $memoryDir "logs"
$wikiDir = Join-Path $memoryDir "wiki\chapters"
$vaultDir = Join-Path $memoryDir "raw\vault"
$inboxDir = Join-Path $memoryDir "raw\inbox"
$indexPath = Join-Path $memoryDir "Index.md"
$mocPath = Join-Path $memoryDir "MOC.md"
$sprintPath = Join-Path $logsDir "ActiveSprintLog.md"
$learningsPath = Join-Path $wikiDir "099_learnings.md"
$today = (Get-Date).ToString("yyyy-MM-dd")

# 1. Initialize Scaffold if missing or requested
if ($Init -or (-not (Test-Path $memoryDir))) {
    Write-Host "Initializing AntiGravity Memory Architecture in $RootDir/memory..." -ForegroundColor Cyan
    @($logsDir, $wikiDir, $vaultDir, $inboxDir) | ForEach-Object {
        if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
    }

    if (-not (Test-Path (Join-Path $vaultDir ".gitkeep"))) {
        Write-Utf8NoBom (Join-Path $vaultDir ".gitkeep") ""
    }
    if (-not (Test-Path (Join-Path $inboxDir ".gitkeep"))) {
        Write-Utf8NoBom (Join-Path $inboxDir ".gitkeep") ""
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
        Write-Utf8NoBom $sprintPath $initialSprint
    }

    if (-not (Test-Path (Join-Path $logsDir "CHANGELOG.md"))) {
        $initialChangelog = @"
# Changelog

## [0.1.0] - $today
### Added
- Initial project scaffolding with AntiGravity Docs-as-Code memory.
"@
        Write-Utf8NoBom (Join-Path $logsDir "CHANGELOG.md") $initialChangelog
    }

    if (-not (Test-Path $mocPath)) {
        $initialMoc = @"
# Map of Content (MOC)

- [Index.md](Index.md) - Primary memory registry and SemVer chapter table
- [ActiveSprintLog.md](logs/ActiveSprintLog.md) - Current sprint state and constraints
- [CHANGELOG.md](logs/CHANGELOG.md) - Versioned milestone history
- [000_overview.md](wiki/chapters/000_overview.md) - System overview and core contracts
- [099_learnings.md](wiki/chapters/099_learnings.md) - Harness2 continuous learnings
"@
        Write-Utf8NoBom $mocPath $initialMoc
    }

    if (-not (Test-Path $indexPath)) {
        $initialIndex = @"
# AntiGravity Memory Index

| ID | Chapter | Domain / Topic | Version |
| :--- | :--- | :--- | :--- |
| CH-000 | [000_overview.md](wiki/chapters/000_overview.md) | High-level system overview & contracts | 1.0.0 |
| CH-099 | [099_learnings.md](wiki/chapters/099_learnings.md) | Continuous learnings & architectural pitfalls | 1.0.0 |
"@
        Write-Utf8NoBom $indexPath $initialIndex
    }

    if (-not (Test-Path (Join-Path $wikiDir "000_overview.md"))) {
        $initialOverview = @"
---
chapter_id: CH-000
version: 1.0.0
status: active
updated: $today
---
# 000: System Overview

## System Identity & Core Contracts
Primary workspace architecture, runtime invariants, and tech stack boundaries.
"@
        Write-Utf8NoBom (Join-Path $wikiDir "000_overview.md") $initialOverview
    }

    if (-not (Test-Path $learningsPath)) {
        $initialLearnings = @"
---
chapter_id: CH-099
version: 1.0.0
status: active
updated: $today
---
# 099: System Learnings & Known Pitfalls

## Architectural Invariants
1. Do not accumulate tool calls in main thread; delegate tasks modifying >=2 files to subagents.
2. Always execute Gate 0 ask_question before drafting specifications or coding.

## 4. Template for Logging New Learnings
``````markdown
### [LRN-YYYY-NNN] <Short Descriptive Title>
- **Date / Trigger:** YYYY-MM-DD / <Command, Test, or Spec Context>
- **Root Cause:** <Technical mechanism of the failure with file/line refs>
- **Anti-Pattern:** <What failed and must be avoided>
- **Deterministic Invariant:** <Concrete, verifiable rule preventing recurrence>
- **Verification Evidence:** <Shielded test command and pass proof>
``````
"@
        Write-Utf8NoBom $learningsPath $initialLearnings
    }
}

# 2. Extract High-Density Context Brief
$brief = [System.Collections.Generic.List[string]]::new()
$brief.Add("# AntiGravity Active Memory Brief")
$brief.Add("> Auto-extracted for immediate working context (Zero Bloat)")

# 2.1 Sprint State (clamp to max 14 lines)
if (Test-Path $sprintPath) {
    $brief.Add("`n## 1. Active Sprint & Decisions")
    $sprintLines = @(Get-Content $sprintPath -Encoding UTF8)
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
        $brief.Add((($sprintLines | Select-Object -First 10) -join "`n"))
    }
}

# 2.2 Domain Chapters from Index.md matching Query
if (Test-Path $indexPath) {
    $brief.Add("`n## 2. Relevant Memory Chapters")
    $indexLines = @(Get-Content $indexPath -Encoding UTF8)
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
        foreach ($mc in ($matchedChapters | Select-Object -First 3)) {
            $brief.Add("- $($mc.Line)")
            $fullChapPath = Join-Path $memoryDir $mc.Path
            if (Test-Path $fullChapPath) {
                $cLines = @(Get-Content $fullChapPath -Encoding UTF8)
                $bodyLines = @()
                $inFm = $false
                foreach ($cl in $cLines) {
                    if ($cl -match '^---') { $inFm = -not $inFm; continue }
                    if (-not $inFm -and $cl.Trim().Length -gt 0) {
                        $bodyLines += "    > " + $cl
                        if ($bodyLines.Count -ge 2) { break }
                    }
                }
                if ($bodyLines.Count -gt 0) {
                    $brief.Add(($bodyLines -join "`n"))
                }
            }
        }
    }
}

# 2.3 Pitfalls from 099_learnings.md (supports both [LRN-YYYY-NNN] and LRN-NNN:, stops before Section 4 template)
if (Test-Path $learningsPath) {
    $brief.Add("`n## 3. Top Architectural Pitfalls (Learnings)")
    $learnLines = @()
    foreach ($ll in @(Get-Content $learningsPath -Encoding UTF8)) {
        if ($ll -match '^##\s+4\.') { break }
        $learnLines += $ll
    }
    $lrnPattern = '^###\s+(?:\[LRN-\d{4}-\d{3}\]|LRN-(?:\d{4}-)?\d{3}:)\s+'
    $lrnHeadings = @($learnLines | Where-Object { $_ -match $lrnPattern })
    if ($lrnHeadings.Count -gt 0) {
        $learningBullets = @($lrnHeadings | Select-Object -Last 5)
    } else {
        $learningBullets = @($learnLines | Where-Object { $_ -match '^[0-9]+\.\s+' } | Select-Object -First 4)
    }
    if ($learningBullets.Count -gt 0) {
        $brief.Add(($learningBullets -join "`n"))
    }
}

$allOutLines = @(($brief -join "`n") -split "`r?`n")
if ($allOutLines.Count -gt 34) {
    $allOutLines = @($allOutLines | Select-Object -First 33) + @("- *(Clamped to <35 lines; see memory/Index.md)*")
}
$allOutLines -join "`n"
exit 0
