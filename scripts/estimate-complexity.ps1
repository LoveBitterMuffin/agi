# estimate-complexity.ps1 - Task Complexity & Resource Allocation Engine (TERA)
param(
    [string]$Description = "Task execution",
    [int]$EstimatedFiles = 1,
    [switch]$IsArchitectural,
    [switch]$HasExternalAPIs,
    [switch]$RequiresBreakingChange,
    [switch]$JsonOutput
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

# 1. Calculate Complexity Score (Bilingual EN/RU via pure-ASCII escapes)
$score = 3
$descLower = $Description.ToLower()

$ruQ = [regex]::Unescape('\u0433\u0434\u0435|\u0447\u0442\u043e|\u043a\u0430\u043a|\u043f\u043e\u0447\u0435\u043c\u0443|\u043a\u0442\u043e|\u043e\u0431\u044a\u044f\u0441\u043d\u0438|\u0441\u0442\u0430\u0442\u0443\u0441|\u043e\u043f\u0438\u0448\u0438|\u043f\u043e\u043a\u0430\u0436\u0438|\u0441\u043f\u0438\u0441\u043e\u043a|\u0440\u0430\u0441\u0441\u043a\u0430\u0436\u0438|\u0431\u0443\u0434\u0435\u0442 \u043b\u0438|\u0441\u043a\u0430\u0436\u0438')
$ruTest = [regex]::Unescape('\u0442\u0435\u0441\u0442|\u043f\u0440\u043e\u0432\u0435\u0440\u044c|\u043f\u0440\u043e\u0442\u0435\u0441\u0442\u0438\u0440\u0443\u0439|\u0437\u0430\u043f\u0443\u0441\u0442\u0438')
$ruInv = [regex]::Unescape('\u0438\u0437\u0443\u0447\u0438|\u0438\u0441\u0441\u043b\u0435\u0434\u0443\u0439|\u0430\u0443\u0434\u0438\u0442|\u043d\u0430\u0439\u0434\u0438|\u043f\u0440\u043e\u0441\u043a\u0430\u043d\u0438\u0440\u0443\u0439')
$ruFix = [regex]::Unescape('\u043f\u043e\u0447\u0438\u043d\u0438|\u043f\u043e\u043f\u0440\u0430\u0432\u044c|\u0438\u0441\u043f\u0440\u0430\u0432\u044c|\u0443\u0434\u0430\u043b\u0438|\u043e\u0431\u043d\u043e\u0432\u0438|\u0434\u043e\u043f\u0438\u0448\u0438|\u043e\u043f\u0442\u0438\u043c\u0438\u0437\u0438\u0440\u0443\u0439|\u0441\u0434\u0435\u043b\u0430\u0439|\u0434\u043e\u0431\u0430\u0432\u044c|\u0441\u043e\u0437\u0434\u0430\u0439|\u0431\u0430\u0433')
$ruArch = [regex]::Unescape('\u0440\u0435\u0444\u0430\u043a\u0442\u043e\u0440|\u043f\u0435\u0440\u0435\u043f\u0438\u0448\u0438|\u0440\u0435\u0434\u0438\u0437\u0430\u0439\u043d|\u043c\u0438\u0433\u0440\u0430\u0446|\u0431\u0435\u0437\u043e\u043f\u0430\u0441\u043d\u043e\u0441\u0442|\u0430\u0440\u0445\u0438\u0442\u0435\u043a\u0442\u0443\u0440|\u0434\u0438\u0437\u0430\u0439\u043d')

$hasMutatingKeyword = ($descLower -match "fix|patch|bug|defect|repair|$ruFix")

# If purely informational question with 0 files and no mutating words, allow Tier 0
if (($EstimatedFiles -eq 0 -or $descLower -match "^(?:what|how|why|explain|status|help|list|show|$ruQ)\b") -and -not $hasMutatingKeyword) {
    if (-not $IsArchitectural -and -not $HasExternalAPIs -and -not $RequiresBreakingChange -and $EstimatedFiles -le 0) {
        $score = 1
    }
}

# File scope impact
if ($EstimatedFiles -gt 5) { $score += 4 }
elseif ($EstimatedFiles -gt 2) { $score += 3 }
elseif ($EstimatedFiles -gt 1) { $score += 2 }

# Operational action keywords automatically trigger elevated subagent mesh
if ($descLower -match "test|run|harness|e2e|unit|$ruTest") { $score += 2 }
if ($descLower -match "investigate|explore|audit|scan|scout|search|$ruInv") { $score += 2 }
if ($hasMutatingKeyword) { $score += 2 }
if ($descLower -match "refactor|rewrite|redesign|migration|security|auth|database|architecture|$ruArch") { $score += 3 }

# Architectural scope impact
if ($IsArchitectural) { $score += 4 }
if ($HasExternalAPIs) { $score += 2 }
if ($RequiresBreakingChange) { $score += 4 }

# 2. Determine Tier & Resource Allocation (mapped to valid native TypeNames & 24 agents)
if ($score -le 2) {
    $tier = "Tier 0 (Fast-Path / Atomic)"
    $tierCode = "T0"
    $modelRecommendation = "flash_lite (fast path)"
    $subagentSwarm = @()
    $specRequired = $false
    $worktreeRequired = $false
    $tokenBudget = "< 1,000 tokens"
    $estimatedDuration = "< 10 seconds"
} elseif ($score -le 5) {
    $tier = "Tier 1 (Standard Slice / Feature & Defect Ping-Pong)"
    $tierCode = "T1"
    $modelRecommendation = "inherit (flash / standard)"
    $subagentSwarm = @("product-manager", "self", "debugger", "security-auditor", "test-engineer")
    $specRequired = $false
    $worktreeRequired = $false
    $tokenBudget = "3,000 - 8,000 tokens"
    $estimatedDuration = "30 - 60 seconds"
} elseif ($score -le 9) {
    $tier = "Tier 2 (Major Feature / Full Relay Mesh)"
    $tierCode = "T2"
    $modelRecommendation = "inherit (pro / high-reasoning)"
    $subagentSwarm = @("product-owner", "explorer-agent", "product-manager", "project-planner", "code-archaeologist", "test-engineer", "self", "debugger", "security-auditor", "qa-automation-engineer", "documentation-writer")
    $specRequired = $true
    $worktreeRequired = $false
    $tokenBudget = "15,000 - 35,000 tokens"
    $estimatedDuration = "2 - 5 minutes"
} else {
    $tier = "Tier 3 (Architectural Epic / System Redesign)"
    $tierCode = "T3"
    $modelRecommendation = "pro (high-reasoning coordinator)"
    $subagentSwarm = @("orchestrator", "product-owner", "explorer-agent", "product-manager", "project-planner", "code-archaeologist", "test-engineer", "self", "debugger", "security-auditor", "qa-automation-engineer", "documentation-writer")
    $specRequired = $true
    $worktreeRequired = $true
    $tokenBudget = "50,000+ tokens"
    $estimatedDuration = "10+ minutes (multi-turn)"
}

$result = [PSCustomObject]@{
    TaskDescription = $Description
    ComplexityScore = $score
    Tier = $tier
    TierCode = $tierCode
    RecommendedModel = $modelRecommendation
    AllocatedSubagents = $subagentSwarm
    SpecRequired = $specRequired
    WorktreeRequired = $worktreeRequired
    TokenBudget = $tokenBudget
    EstimatedDuration = $estimatedDuration
}

if ($JsonOutput) {
    $result | ConvertTo-Json -Depth 3
} else {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  TERA: Task Complexity & Resource Allocator" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Task: $Description" -ForegroundColor White
    Write-Host "Score: $score / 12  ->  $tier" -ForegroundColor $(if ($score -le 2) { "Green" } elseif ($score -le 5) { "Cyan" } elseif ($score -le 9) { "Yellow" } else { "Red" })
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Model Tier:        $modelRecommendation" -ForegroundColor White
    Write-Host "Token Budget:      $tokenBudget" -ForegroundColor White
    Write-Host "Estimated Time:    $estimatedDuration" -ForegroundColor White
    Write-Host "Spec-First Gate:   $(if ($specRequired) { 'MANDATORY (SPEC-YYYY-NNN)' } else { 'Fast-Path / Optional' })" -ForegroundColor $(if ($specRequired) { "Yellow" } else { "Green" })
    Write-Host "Git Worktree:      $(if ($worktreeRequired) { 'YES (isolated branch)' } else { 'NO (main workspace)' })" -ForegroundColor White
    Write-Host "Subagents Swarm:   $(if ($subagentSwarm.Count -eq 0) { 'None (Parent Agent Direct)' } else { $subagentSwarm -join ', ' })" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
}
