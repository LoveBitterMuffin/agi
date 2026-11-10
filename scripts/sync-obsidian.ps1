# sync-obsidian.ps1 - Automated Obsidian Canvas & Architecture Synchronizer
param(
    [string]$OutputFile = "memory\Architecture.canvas",
    [string]$RootDir = ""
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Obsidian Architecture Canvas Generator  " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if ($RootDir) {
    $repoRoot = [System.IO.Path]::GetFullPath($RootDir)
} else {
    $cwd = (Get-Location).ProviderPath
    $gitTop = (git -C $cwd rev-parse --show-toplevel 2>$null)
    $homeNorm = [System.IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
    $cwdNorm = [System.IO.Path]::GetFullPath($cwd).TrimEnd('\', '/')
    $repoRoot = if ($gitTop -and ([System.IO.Path]::GetFullPath($gitTop).TrimEnd('\', '/') -ne $homeNorm -or $cwdNorm -eq $homeNorm)) { $gitTop } else { $cwd }
}
$outPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) { $OutputFile } else { Join-Path $repoRoot $OutputFile }

$vaultDir = Join-Path $repoRoot "memory\raw\vault"
$wikiDir = Join-Path $repoRoot "memory\wiki\chapters"

$vaultFiles = if (Test-Path $vaultDir) {
    @(Get-ChildItem -Path (Join-Path $vaultDir "*") -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @(".md", ".json") -and $_.Name -ne ".gitkeep" } | Sort-Object Name)
} else { @() }
$wikiFiles = if (Test-Path $wikiDir) {
    @(Get-ChildItem -Path (Join-Path $wikiDir "*") -File -Filter "*.md" -ErrorAction SilentlyContinue | Sort-Object Name)
} else { @() }

$nodes = @()
$edges = @()

# 1. Title Banner Node
$nodes += @{
    id = "banner-title"
    type = "text"
    text = "# AntiGravity Autonomous Multi-Agent Relay Architecture`n`n**Interactive 2D Knowledge Graph & Subagent Swarm Mesh**`n`n- **Layer 1 (Purple):** Immutable Raw Vault Documents`n- **Layer 2 (Green):** Compiled Wiki Knowledge Chapters`n- **Swarm (Cyan):** Autonomous Subagents Relay Mesh`n- **Governance (Yellow):** Ponytail Ladder of Restraint (YAGNI & Anti-Bloat)"
    x = -200
    y = -650
    width = 850
    height = 200
    color = "5"
}

# 2. Layer 1 Nodes (Vault - Purple: color "6")
$startX_vault = -700
$startY_vault = -450
$spacingY_vault = 130

for ($i = 0; $i -lt $vaultFiles.Count; $i++) {
    $f = $vaultFiles[$i]
    $relFile = "memory/raw/vault/" + $f.Name
    $nodeId = "vault-" + ($f.Name -replace '[^a-zA-Z0-9]', '_')
    $nodes += @{
        id = $nodeId
        type = "file"
        file = $relFile
        x = $startX_vault
        y = $startY_vault + ($i * $spacingY_vault)
        width = 380
        height = 110
        color = "6"
    }
}

# 3. Layer 2 Nodes (Wiki - Green: color "4")
$startX_wiki = 0
$startY_wiki = -450
$spacingY_wiki = 115

for ($i = 0; $i -lt $wikiFiles.Count; $i++) {
    $f = $wikiFiles[$i]
    $relFile = "memory/wiki/chapters/" + $f.Name
    $nodeId = "wiki-" + ($f.Name -replace '[^a-zA-Z0-9]', '_')
    $nodes += @{
        id = $nodeId
        type = "file"
        file = $relFile
        x = $startX_wiki
        y = $startY_wiki + ($i * $spacingY_wiki)
        width = 400
        height = 100
        color = "4"
    }
}

# 4. Swarm Nodes (Cyan: color "5") - Subagent Mesh
$botEmoji = [char]::ConvertFromUtf32(0x1F916)

$swarmCol1 = @(
    @{ Name = "product-owner"; Role = "Frontline Inquirer & Checkpoint Gate"; Desc = "Clarifies intent, options via ask_question (Gate 0)" },
    @{ Name = "explorer-agent"; Role = "Codebase & Tool Topology Scout"; Desc = "Read-only AST inspection and context7 documentation" },
    @{ Name = "product-manager"; Role = "Spec Auditor & AC Matrix"; Desc = "Extracts AC matrix, boundary cases, SemVer impact" },
    @{ Name = "project-planner"; Role = "Architecture & Dependency Planner"; Desc = "Designs WBS, dependency graph, and risk matrix" },
    @{ Name = "code-archaeologist"; Role = "Reuse & Restraint Auditor"; Desc = "Enforces 7-rung YAGNI and legacy refactoring bounds" },
    @{ Name = "orchestrator"; Role = "Multi-Agent Swarm Conductor"; Desc = "Coordinates parallel dispatch and synthesis gates" }
)

$swarmCol2 = @(
    @{ Name = "test-engineer"; Role = "Unit & Integration Test Architect"; Desc = "Writes machine-checked unit and integration tests" },
    @{ Name = "security-auditor"; Role = "Adversarial Code & Security Reviewer"; Desc = "Audits security, bounds, test coverage & docs" },
    @{ Name = "debugger"; Role = "Surgical Defect Patcher (Ping-Pong)"; Desc = "Atomic fixes to flagged lines until review approval" },
    @{ Name = "qa-automation-engineer"; Role = "Harness & E2E Runner"; Desc = "Executes 4-stage harness isolating console logs" },
    @{ Name = "documentation-writer"; Role = "Memory Compiler & SemVer Auditor"; Desc = "Handles /wiki-ingest, /wiki-brief, /release-audit" },
    @{ Name = "devops-engineer"; Role = "Automation & CI/CD Specialist"; Desc = "Maintains shielded runners, worktrees, and hooks" }
)

for ($i = 0; $i -lt $swarmCol1.Count; $i++) {
    $ag = $swarmCol1[$i]
    $nodes += @{
        id = "swarm-" + $ag.Name
        type = "text"
        text = "### $botEmoji $($ag.Name)`n**Role:** $($ag.Role)`n`n$($ag.Desc)"
        x = 520
        y = -350 + ($i * 140)
        width = 360
        height = 120
        color = "5"
    }
}

for ($i = 0; $i -lt $swarmCol2.Count; $i++) {
    $ag = $swarmCol2[$i]
    $nodes += @{
        id = "swarm-" + $ag.Name
        type = "text"
        text = "### $botEmoji $($ag.Name)`n**Role:** $($ag.Role)`n`n$($ag.Desc)"
        x = 920
        y = -350 + ($i * 140)
        width = 360
        height = 120
        color = "5"
    }
}

# 5. Governance Node (Yellow: color "3")
$nodes += @{
    id = "governance-ladder"
    type = "text"
    text = "### Ponytail Ladder of Restraint`n*'The best code is the code you never wrote.'*`n`n1. **YAGNI:** Does it need to exist at all?`n2. **Re-use:** Already in this codebase?`n3. **Stdlib:** Does the standard library do it?`n4. **Platform:** Native host OS / shell feature?`n5. **Dependencies:** Already installed package?`n6. **Minimal:** Can it be one clean line/function?`n7. **Minimum Code:** Only then, the minimum that works + 1 test."
    x = 520
    y = 520
    width = 760
    height = 240
    color = "3"
}

$nodeIdSet = [System.Collections.Generic.HashSet[string]]::new()
foreach ($n in $nodes) { [void]$nodeIdSet.Add($n.id) }

function Add-SafeEdge {
    param($id, $from, $to, $label, $color)
    if ($nodeIdSet.Contains($from) -and $nodeIdSet.Contains($to)) {
        $script:edges += @{
            id = $id
            fromNode = $from
            toNode = $to
            label = $label
            color = $color
        }
    }
}

# 6. Dynamic Edges: Connect Vault to Wiki (Lossless Pointers)
$edgeIndex = 1
foreach ($wf in $wikiFiles) {
    $wikiNodeId = "wiki-" + ($wf.Name -replace '[^a-zA-Z0-9]', '_')
    $content = Get-Content $wf.FullName -Raw -Encoding UTF8
    $rawMatches = [regex]::Matches($content, '(RAW-(?:SPEC-)?[0-9]{4}-[0-9]{3}(?:_[a-zA-Z0-9_\-\.]+?)?\.md)')
    foreach ($m in $rawMatches) {
        $rawFileName = $m.Groups[1].Value
        $vaultNodeId = "vault-" + ($rawFileName -replace '[^a-zA-Z0-9]', '_')
        Add-SafeEdge -id "edge-dyn-v$edgeIndex" -from $vaultNodeId -to $wikiNodeId -label "Lossless Pointer" -color "6"
        $edgeIndex++
    }
}

# 7. Wiki Lineage Edges (000_overview to other chapters)
$overviewNodeId = "wiki-000_overview_md"
if ($nodeIdSet.Contains($overviewNodeId)) {
    foreach ($wf in $wikiFiles) {
        if ($wf.Name -ne "000_overview.md") {
            $targetWikiNodeId = "wiki-" + ($wf.Name -replace '[^a-zA-Z0-9]', '_')
            Add-SafeEdge -id "edge-overview-$targetWikiNodeId" -from $overviewNodeId -to $targetWikiNodeId -label "Subsystem Contract" -color "4"
        }
    }
}

# 8. Swarm Baton-Relay Cycle Edges
Add-SafeEdge -id "edge-relay-0-1" -from "swarm-orchestrator" -to "swarm-product-owner" -label "0. Gate 0 Inquiry" -color "5"
Add-SafeEdge -id "edge-relay-1-2" -from "swarm-product-owner" -to "swarm-explorer-agent" -label "1. Clarified" -color "5"
Add-SafeEdge -id "edge-relay-2-3" -from "swarm-explorer-agent" -to "swarm-product-manager" -label "2. Topology Mapped" -color "5"
Add-SafeEdge -id "edge-relay-3-4" -from "swarm-product-manager" -to "swarm-project-planner" -label "3. Draft Spec" -color "5"
Add-SafeEdge -id "edge-relay-4-5" -from "swarm-project-planner" -to "swarm-code-archaeologist" -label "4. Plan Approved" -color "5"
Add-SafeEdge -id "edge-relay-5-6" -from "swarm-code-archaeologist" -to "swarm-test-engineer" -label "5. Ponytail Check" -color "5"
Add-SafeEdge -id "edge-relay-6-7" -from "swarm-test-engineer" -to "swarm-security-auditor" -label "6. TDD Tests" -color "5"
Add-SafeEdge -id "edge-relay-7-8" -from "swarm-security-auditor" -to "swarm-debugger" -label "7A. Defect Finding" -color "1"
Add-SafeEdge -id "edge-relay-8-7" -from "swarm-debugger" -to "swarm-security-auditor" -label "7B. Patch Loop" -color "2"
Add-SafeEdge -id "edge-relay-7-9" -from "swarm-security-auditor" -to "swarm-qa-automation-engineer" -label "8. APPROVED" -color "4"
Add-SafeEdge -id "edge-relay-9-10" -from "swarm-qa-automation-engineer" -to "swarm-documentation-writer" -label "9. Harness PASS" -color "4"
Add-SafeEdge -id "edge-relay-10-0" -from "swarm-documentation-writer" -to "swarm-orchestrator" -label "10. Memory Synced" -color "4"
Add-SafeEdge -id "edge-sw-gov" -from "swarm-code-archaeologist" -to "governance-ladder" -label "Enforces Restraint" -color "3"

# 9. Serialize to Obsidian Canvas JSON
$canvasObj = @{
    nodes = $nodes
    edges = $edges
}

$outDir = Split-Path -Parent $outPath
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$json = $canvasObj | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($outPath, $json, $utf8NoBom)

Write-Host "[SUCCESS] Generated Obsidian Architecture Canvas at $outPath" -ForegroundColor Green
Write-Host "          Nodes: $($nodes.Count) (Vault: $($vaultFiles.Count), Wiki: $($wikiFiles.Count), Swarm: 12, Governance: 1)" -ForegroundColor DarkGray
Write-Host "          Edges: $($edges.Count) (Lossless pointers + Swarm relay)" -ForegroundColor DarkGray
