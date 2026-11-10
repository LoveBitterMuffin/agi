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
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

$cwd = (Get-Location).ProviderPath
$gitTop = (git -C $cwd rev-parse --show-toplevel 2>$null)
$homeNorm = [System.IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
$cwdNorm = [System.IO.Path]::GetFullPath($cwd).TrimEnd('\', '/')
$repoRoot = if ($gitTop -and ([System.IO.Path]::GetFullPath($gitTop).TrimEnd('\', '/') -ne $homeNorm -or $cwdNorm -eq $homeNorm)) { $gitTop } else { $cwd }

# 1. Run Complexity Estimation via TERA using PSScriptRoot
$teraScript = Join-Path $PSScriptRoot "estimate-complexity.ps1"
if (-not (Test-Path $teraScript)) {
    $teraScript = Join-Path $repoRoot ".agents\scripts\estimate-complexity.ps1"
}
$teraParams = @{
    Description = $Task
    EstimatedFiles = $EstimatedFiles
    JsonOutput = $true
}
if ($IsArchitectural) { $teraParams.IsArchitectural = $true }
if ($HasExternalAPIs) { $teraParams.HasExternalAPIs = $true }

$teraRaw = & $teraScript @teraParams | Out-String
$tera = $teraRaw | ConvertFrom-Json

# 2. Build Deterministic Relay Sequence mapped to valid native TypeNames & 24 plugin agents
$relayPlan = @()

if ($tera.TierCode -eq "T0") {
    $relayPlan += @{
        Step = 1
        Role = "Main Agent"
        TypeName = "self"
        Subagent = "orchestrator"
        Action = "Fast-Path Direct Execution (read-only / single-line fix)"
        Gating = "None"
    }
} elseif ($tera.TierCode -eq "T1") {
    $relayPlan += @{
        Step = 1
        Role = "Spec Verifier"
        TypeName = "research"
        Subagent = "product-manager"
        Action = "Extract AC-xx matrix & verify negative paths"
        Gating = "Auto-pass if deterministic"
    }
    $relayPlan += @{
        Step = 2
        Role = "Implementation Worker"
        TypeName = "self"
        Subagent = "self"
        Action = "Write clean minimal logic"
        Gating = "Must pass unit tests"
    }
    $relayPlan += @{
        Step = 3
        Role = "Adversarial Code Reviewer"
        TypeName = "research"
        Subagent = "security-auditor"
        Action = "Audit git diff for security and bounds"
        Gating = "CHANGES_REQUESTED triggers Step 4; APPROVED proceeds to Step 5"
    }
    $relayPlan += @{
        Step = 4
        Role = "Surgical Defect Fixer"
        TypeName = "self"
        Subagent = "debugger"
        Action = "Apply atomic patch to reviewer findings (Ping-Pong)"
        Gating = "Loop back to Step 3 (Max 2 cycles)"
    }
    $relayPlan += @{
        Step = 5
        Role = "Verification Runner"
        TypeName = "self"
        Subagent = "test-engineer"
        Action = "Execute .agents/harness/run-harness.ps1 (4 stages)"
        Gating = "Exit code 0 required"
    }
} else {
    $relayPlan += @{ Step = 1;  Role = "User Interviewer";      TypeName = "research"; Subagent = "product-owner";          Action = "Inquiry & options via ask_question"; Gating = "User confirmation" }
    $relayPlan += @{ Step = 2;  Role = "Tool & Codebase Scout"; TypeName = "research"; Subagent = "explorer-agent";         Action = "Match MCP servers & map codebase symbols"; Gating = "No duplicate tools" }
    $relayPlan += @{ Step = 3;  Role = "Spec Verifier";         TypeName = "research"; Subagent = "product-manager";        Action = "Draft SPEC-YYYY-NNN & acceptance matrix"; Gating = "Zero ambiguity" }
    $relayPlan += @{ Step = 4;  Role = "Architecture Critic";   TypeName = "research"; Subagent = "project-planner";        Action = "Stress-test architecture & dependency graph"; Gating = "Reject brittle plans" }
    $relayPlan += @{ Step = 5;  Role = "Ponytail Guardian";     TypeName = "research"; Subagent = "code-archaeologist";     Action = "Enforce 7-rung YAGNI & reuse scan"; Gating = "Strict stdlib first" }
    $relayPlan += @{ Step = 6;  Role = "Test Architect";        TypeName = "self";     Subagent = "test-engineer";          Action = "Write unit & integration tests (Red Phase)"; Gating = "Tests must fail initially" }
    $relayPlan += @{ Step = 7;  Role = "Implementation Worker"; TypeName = "self";     Subagent = "self";                   Action = "Write minimal production logic"; Gating = "Compile & pass tests" }
    $relayPlan += @{ Step = 8;  Role = "Code Reviewer";         TypeName = "research"; Subagent = "security-auditor";       Action = "Adversarial diff & security review"; Gating = "Ping-pong on findings" }
    $relayPlan += @{ Step = 9;  Role = "Defect Fixer";          TypeName = "self";     Subagent = "debugger";               Action = "Surgical atomic patch (Max 2 cycles)"; Gating = "Repeat Step 8 until APPROVED" }
    $relayPlan += @{ Step = 10; Role = "Harness Runner";        TypeName = "self";     Subagent = "qa-automation-engineer"; Action = "Run run-harness.ps1 4 stages"; Gating = "Exit code 0" }
    $relayPlan += @{ Step = 11; Role = "Context Keeper";        TypeName = "self";     Subagent = "documentation-writer";   Action = "Compile memory, SemVer bump, release audit"; Gating = "audit-memory PASS" }
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
        Write-Host "$prefix $($st.Role) ($($st.Subagent) | TypeName: $($st.TypeName))" -ForegroundColor Green
        Write-Host "     Action: $($st.Action)" -ForegroundColor Gray
        Write-Host "     Gating: $($st.Gating)" -ForegroundColor DarkGray
    }

    Write-Host "==========================================" -ForegroundColor Cyan
}
