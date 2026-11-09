# dispatch-relay.ps1 - Autonomous Swarm Relay Orchestrator & Task Dispatcher
param(
    [Parameter(Mandatory=$true)]
    [string]$Task,
    [int]$EstimatedFiles = 1,
    [switch]$IsArchitectural,
    [switch]$HasExternalAPIs,
    [switch]$DryRun,
    [switch]$JsonOutput
)

$ErrorActionPreference = "Stop"

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

# 1. Run Complexity Estimation via TERA
$teraScript = Join-Path $repoRoot ".agents\scripts\estimate-complexity.ps1"
$teraParams = @{
    Description = $Task
    EstimatedFiles = $EstimatedFiles
    JsonOutput = $true
}
if ($IsArchitectural) { $teraParams.IsArchitectural = $true }
if ($HasExternalAPIs) { $teraParams.HasExternalAPIs = $true }

$teraRaw = & $teraScript @teraParams | Out-String
$tera = $teraRaw | ConvertFrom-Json

# 2. Build Deterministic Relay Sequence
$relayPlan = @()

if ($tera.TierCode -eq "T0") {
    $relayPlan += @{
        Step = 1
        Role = "Main Agent"
        Subagent = "self"
        Action = "Fast-Path Direct Execution (<250 lines)"
        Gating = "None"
    }
} elseif ($tera.TierCode -eq "T1") {
    $relayPlan += @{
        Step = 1
        Role = "Spec Verifier"
        Subagent = "spec-verifier"
        Action = "Extract AC-xx matrix & verify negative paths"
        Gating = "Auto-pass if deterministic"
    }
    $relayPlan += @{
        Step = 2
        Role = "Implementation Worker"
        Subagent = "self"
        Action = "Write clean minimal logic"
        Gating = "Must pass unit tests"
    }
    $relayPlan += @{
        Step = 3
        Role = "Adversarial Code Reviewer"
        Subagent = "code-reviewer"
        Action = "Audit git diff for security and bounds"
        Gating = "CHANGES_REQUESTED triggers Step 4; APPROVED proceeds to Step 5"
    }
    $relayPlan += @{
        Step = 4
        Role = "Surgical Defect Fixer"
        Subagent = "defect-fixer"
        Action = "Apply atomic patch to reviewer findings (Ping-Pong)"
        Gating = "Loop back to Step 3 (Max 3 cycles)"
    }
    $relayPlan += @{
        Step = 5
        Role = "Verification Runner"
        Subagent = "test-runner"
        Action = "Execute .agents/harness/run-harness.ps1 (4 stages)"
        Gating = "Exit code 0 required"
    }
} else {
    # Tier 2 / Tier 3: Full 11-Subagent Relay Mesh
    $relayPlan += @{ Step = 1; Role = "User Interviewer"; Subagent = "user-interviewer"; Action = "Inquiry & options via ask_question"; Gating = "User confirmation" }
    $relayPlan += @{ Step = 2; Role = "Tool Curator"; Subagent = "tool-curator"; Action = "Match MCP servers & marketplace plugins"; Gating = "No duplicate tools" }
    $relayPlan += @{ Step = 3; Role = "Spec Verifier"; Subagent = "spec-verifier"; Action = "Draft SPEC-YYYY-NNN & acceptance matrix"; Gating = "Zero ambiguity" }
    $relayPlan += @{ Step = 4; Role = "Solution Critic"; Subagent = "solution-critic"; Action = "Stress-test architecture & failover"; Gating = "Reject brittle plans" }
    $relayPlan += @{ Step = 5; Role = "Ponytail Guardian"; Subagent = "ponytail-guardian"; Action = "Enforce 7-rung YAGNI, slash 50% code"; Gating = "Strict stdlib first" }
    $relayPlan += @{ Step = 6; Role = "Test Architect"; Subagent = "test-architect"; Action = "Write unit & E2E tests (Red Phase)"; Gating = "Tests must fail initially" }
    $relayPlan += @{ Step = 7; Role = "Implementation Worker"; Subagent = "self"; Action = "Write minimal production logic"; Gating = "Compile & pass tests" }
    $relayPlan += @{ Step = 8; Role = "Code Reviewer"; Subagent = "code-reviewer"; Action = "Adversarial diff review"; Gating = "Ping-pong on findings" }
    $relayPlan += @{ Step = 9; Role = "Defect Fixer"; Subagent = "defect-fixer"; Action = "Surgical atomic patch"; Gating = "Repeat Step 8 until APPROVED" }
    $relayPlan += @{ Step = 10; Role = "Harness Runner"; Subagent = "test-runner"; Action = "Run run-harness.ps1 4 stages"; Gating = "Exit code 0" }
    $relayPlan += @{ Step = 11; Role = "Context Keeper"; Subagent = "context-keeper"; Action = "Compile memory, SemVer bump, canvas sync"; Gating = "audit-memory PASS" }
}

$outputObj = [PSCustomObject]@{
    Task = $Task
    ComplexityScore = $tera.ComplexityScore
    Tier = $tera.Tier
    TierCode = $tera.TierCode
    TokenBudget = $tera.TokenBudget
    SpecRequired = $tera.SpecRequired
    RelayStepsCount = $relayPlan.Count
    RelayPlan = $relayPlan
}

if ($JsonOutput) {
    $outputObj | ConvertTo-Json -Depth 5
} else {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  AntiGravity Swarm Relay Orchestrator    " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Task: $Task" -ForegroundColor White
    Write-Host "Classification: $($tera.Tier) (Score: $($tera.ComplexityScore))" -ForegroundColor $(if ($tera.TierCode -eq "T0") { "Green" } elseif ($tera.TierCode -eq "T1") { "Cyan" } else { "Yellow" })
    Write-Host "Token Budget:   $($tera.TokenBudget)" -ForegroundColor White
    Write-Host "Spec-First:     $($tera.SpecRequired)" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Deterministic Relay Sequence ($($relayPlan.Count) steps):" -ForegroundColor Yellow

    foreach ($st in $relayPlan) {
        $prefix = "[$($st.Step)]"
        Write-Host "$prefix $($st.Role) ($($st.Subagent))" -ForegroundColor Green
        Write-Host "     Action: $($st.Action)" -ForegroundColor Gray
        Write-Host "     Gating: $($st.Gating)" -ForegroundColor DarkGray
    }

    Write-Host "==========================================" -ForegroundColor Cyan
}
