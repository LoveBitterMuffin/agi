# sync-obsidian.ps1 - Automated Obsidian Canvas & Architecture Synchronizer
param(
    [string]$OutputFile = "memory\Architecture.canvas"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Obsidian Architecture Canvas Generator  " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
$outPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) { $OutputFile } else { Join-Path $repoRoot $OutputFile }

$vaultDir = Join-Path $repoRoot "memory\raw\vault"
$wikiDir = Join-Path $repoRoot "memory\wiki\chapters"

$vaultFiles = @(Get-ChildItem -Path (Join-Path $vaultDir "*") -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @(".md", ".json") -and $_.Name -ne ".gitkeep" } | Sort-Object Name)
$wikiFiles = @(Get-ChildItem -Path (Join-Path $wikiDir "*") -File -Filter "*.md" -ErrorAction SilentlyContinue | Sort-Object Name)

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
    @{ Name = "prompt-engineer"; Role = "Meta-Prompt & Anti-Bloat Architect"; Desc = "Structures 4-part subagent prompts & shields context" },
    @{ Name = "user-interviewer"; Role = "Frontline Inquirer & Checkpoint Gate"; Desc = "Clarifies intent, options via ask_question (Gate 0)" },
    @{ Name = "tool-curator"; Role = "Tool, MCP & Skill Matchmaker"; Desc = "Matches chrome-devtools, context7, marketplace plugins" },
    @{ Name = "spec-verifier"; Role = "Spec Auditor & Risk Forecaster"; Desc = "Extracts AC matrix, boundary cases, SemVer impact" },
    @{ Name = "solution-critic"; Role = "Adversarial Solution Critic"; Desc = "Stress-tests design, rejects brittle abstractions" },
    @{ Name = "ponytail-guardian"; Role = "Senior Sloth (Ponytail Restraint)"; Desc = "Enforces 7-rung YAGNI, slashes code by -50%" }
)

$swarmCol2 = @(
    @{ Name = "test-architect"; Role = "Full-Spectrum & E2E Test Architect"; Desc = "Writes machine unit, integration & browser tests" },
    @{ Name = "code-reviewer"; Role = "Adversarial Code & Diff Reviewer"; Desc = "Audits security, bounds, test coverage & docs" },
    @{ Name = "defect-fixer"; Role = "Surgical Defect Patcher (Ping-Pong)"; Desc = "Atomic fixes to flagged lines until review approval" },
    @{ Name = "test-runner"; Role = "Harness Runner (run-harness.ps1)"; Desc = "Executes 4-stage harness isolating console logs" },
    @{ Name = "context-keeper"; Role = "Memory Compiler & SemVer Auditor"; Desc = "Handles /wiki-ingest, /wiki-brief, /release-audit" },
    @{ Name = "codebase-scout"; Role = "Topology & Context7 Scout"; Desc = "Read-only AST inspection and up-to-date documentation" }
)

# Render Column 1 (Planning & Design: X=520)
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

# Render Column 2 (Testing, Review & Memory: X=920)
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

# Build Fast Node Set
$nodeIdSet = [System.Collections.Generic.HashSet[string]]::new()
foreach ($n in $nodes) { [void]$nodeIdSet.Add($n.id) }

# Helper to safely add an edge
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
    $content = Get-Content $wf.FullName -Raw
    
    # Match any RAW-*.md or RAW-SPEC-*.md pointers
    $matches = [regex]::Matches($content, '(RAW-(?:SPEC-)?[0-9]{4}-[0-9]{3}_[a-zA-Z0-9_\-\.]+?\.md)')
    foreach ($m in $matches) {
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
Add-SafeEdge -id "edge-relay-0-1" -from "swarm-prompt-engineer" -to "swarm-user-interviewer" -label "0. Prompt Brief" -color "5"
Add-SafeEdge -id "edge-relay-1-2" -from "swarm-user-interviewer" -to "swarm-tool-curator" -label "1. Gate 0 Clarified" -color "5"
Add-SafeEdge -id "edge-relay-2-3" -from "swarm-tool-curator" -to "swarm-spec-verifier" -label "2. Tools Matched" -color "5"
Add-SafeEdge -id "edge-relay-3-4" -from "swarm-spec-verifier" -to "swarm-solution-critic" -label "3. Draft Spec" -color "5"
Add-SafeEdge -id "edge-relay-4-5" -from "swarm-solution-critic" -to "swarm-ponytail-guardian" -label "4. Plan Approved" -color "5"
Add-SafeEdge -id "edge-relay-5-6" -from "swarm-ponytail-guardian" -to "swarm-test-architect" -label "5. -50% YAGNI" -color "5"
Add-SafeEdge -id "edge-relay-6-7" -from "swarm-test-architect" -to "swarm-code-reviewer" -label "6. TDD Tests" -color "5"
Add-SafeEdge -id "edge-relay-7-8" -from "swarm-code-reviewer" -to "swarm-defect-fixer" -label "7A. Defect Finding" -color "1"
Add-SafeEdge -id "edge-relay-8-7" -from "swarm-defect-fixer" -to "swarm-code-reviewer" -label "7B. Patch Loop" -color "2"
Add-SafeEdge -id "edge-relay-7-9" -from "swarm-code-reviewer" -to "swarm-test-runner" -label "8. APPROVED" -color "4"
Add-SafeEdge -id "edge-relay-9-10" -from "swarm-test-runner" -to "swarm-context-keeper" -label "9. Harness PASS" -color "4"
Add-SafeEdge -id "edge-relay-10-11" -from "swarm-context-keeper" -to "swarm-codebase-scout" -label "10. Memory Compiled" -color "4"
Add-SafeEdge -id "edge-relay-11-0" -from "swarm-codebase-scout" -to "swarm-prompt-engineer" -label "11. Next Cycle" -color "5"
Add-SafeEdge -id "edge-sw-gov" -from "swarm-ponytail-guardian" -to "governance-ladder" -label "Enforces Restraint" -color "3"

# 9. Serialize to Obsidian Canvas JSON
$canvasObj = @{
    nodes = $nodes
    edges = $edges
}

$json = $canvasObj | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($outPath, $json, [System.Text.Encoding]::UTF8)

Write-Host "[SUCCESS] Generated Obsidian Architecture Canvas at $outPath" -ForegroundColor Green
Write-Host "          Nodes: $($nodes.Count) (Vault: $($vaultFiles.Count), Wiki: $($wikiFiles.Count), Swarm: 12, Governance: 1)" -ForegroundColor DarkGray
Write-Host "          Edges: $($edges.Count) (Lossless pointers + Swarm relay)" -ForegroundColor DarkGray
