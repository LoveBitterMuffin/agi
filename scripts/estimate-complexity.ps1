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

# 1. Calculate Complexity Score (Subagent-First Default Doctrine)
# Default stance: Subagent delegation is preferred; Tier 0 fast-path is strictly for zero-tool text queries.
$score = 3

$descLower = $Description.ToLower()

# If purely informational question with 0 files, allow Tier 0
if ($EstimatedFiles -eq 0 -or $descLower -match "^(?:what|how|why|explain|status|help|list|show)\b") {
    if (-not $IsArchitectural -and -not $HasExternalAPIs -and -not $RequiresBreakingChange -and $EstimatedFiles -le 0) {
        $score = 1
    }
}

# File scope impact
if ($EstimatedFiles -gt 5) { $score += 4 }
elseif ($EstimatedFiles -gt 2) { $score += 3 }
elseif ($EstimatedFiles -gt 1) { $score += 2 }

# Operational action keywords automatically trigger elevated subagent mesh
if ($descLower -match "test|run|harness|e2e|unit") { $score += 2 }
if ($descLower -match "investigate|explore|audit|scan|scout|search") { $score += 2 }
if ($descLower -match "fix|patch|bug|defect|repair") { $score += 2 }
if ($descLower -match "refactor|rewrite|redesign|migration|security|auth|database|architecture") { $score += 3 }

# Architectural scope impact
if ($IsArchitectural) { $score += 4 }
if ($HasExternalAPIs) { $score += 2 }
if ($RequiresBreakingChange) { $score += 4 }

# 2. Determine Tier & Resource Allocation
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
    $subagentSwarm = @("spec-verifier", "self (worker)", "defect-fixer", "code-reviewer", "test-runner")
    $specRequired = $false
    $worktreeRequired = $false
    $tokenBudget = "3,000 - 8,000 tokens"
    $estimatedDuration = "30 - 60 seconds"
} elseif ($score -le 9) {
    $tier = "Tier 2 (Major Feature / Full Relay Mesh)"
    $tierCode = "T2"
    $modelRecommendation = "inherit (pro / high-reasoning)"
    $subagentSwarm = @("user-interviewer", "tool-curator", "spec-verifier", "solution-critic", "ponytail-guardian", "test-architect", "self (worker)", "defect-fixer", "code-reviewer", "test-runner", "context-keeper", "codebase-scout")
    $specRequired = $true
    $worktreeRequired = $false
    $tokenBudget = "15,000 - 35,000 tokens"
    $estimatedDuration = "2 - 5 minutes"
} else {
    $tier = "Tier 3 (Architectural Epic / System Redesign)"
    $tierCode = "T3"
    $modelRecommendation = "pro (high-reasoning coordinator)"
    $subagentSwarm = @("user-interviewer", "tool-curator", "spec-verifier", "solution-critic", "ponytail-guardian", "test-architect", "self (parallel workers)", "defect-fixer", "code-reviewer", "test-runner", "context-keeper", "codebase-scout")
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
