# assemble-swarm.ps1 - Just-In-Time (JIT) Swarm Assembler and Orchestration Engine
param(
    [Parameter(Mandatory=$true)]
    [string]$Task,
    [switch]$Json
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

$taskLower = $Task.ToLower()

# 1. Domain Detection (EN/RU via pure-ASCII escapes)
$ruUI = [regex]::Unescape('\u0434\u0438\u0437\u0430\u0439\u043d|\u0441\u0442\u0438\u043b|\u0432\u0435\u0440\u0441\u0442\u043a|\u043a\u043e\u043c\u043f\u043e\u043d\u0435\u043d\u0442|\u043a\u043d\u043e\u043f\u043a|\u0432\u0438\u0434\u0436\u0435\u0442|\u043f\u0430\u043b\u0438\u0442\u0440|\u043c\u043e\u0434\u0430\u043b\u043a|\u0441\u0442\u0440\u0430\u043d\u0438\u0446|\u0430\u043d\u0438\u043c\u0430\u0446\u0438|\u0433\u0435\u043a\u0441\u0430\u0433\u043e\u043d|\u0445\u0435\u043a\u0441\u0430\u0433\u043e\u043d|\u043a\u0430\u0431\u0438\u043d\u0435\u0442|\u043a\u0430\u0440\u0442\u043e\u0447\u043a')
$ruDom = [regex]::Unescape('\u0441\u0435\u0440\u0432\u0438\u0441|\u0440\u043e\u043b|\u0433\u0440\u0443\u043f\u043f|\u043e\u043f\u043b\u0430\u0442|\u0430\u0434\u0430\u043f\u0442\u0435\u0440|\u043c\u043e\u0434\u0435\u043b|\u0431\u044d\u043a\u0435\u043d\u0434|\u043b\u043e\u0433\u0438\u043a')
$ruRes = [regex]::Unescape('\u0438\u0437\u0443\u0447\u0438|\u0438\u0441\u0441\u043b\u0435\u0434\u0443\u0439|\u0434\u043e\u043a\u0443\u043c\u0435\u043d\u0442\u0430\u0446\u0438|\u0430\u043d\u0430\u043b\u043e\u0433|\u043a\u043e\u043d\u043a\u0443\u0440\u0435\u043d\u0442|\u043d\u0430\u0439\u0434\u0438')
$ruQA = [regex]::Unescape('\u0442\u0435\u0441\u0442|\u043f\u0440\u043e\u0432\u0435\u0440\u044c|\u0430\u0443\u0434\u0438\u0442|\u0440\u0435\u0433\u0440\u0435\u0441\u0441')

$isUI = $taskLower -match "(?:ui|ux|css|landing|frontend|$ruUI)"
$isDomain = $taskLower -match "(?:auth|crm|payment|api|backend|service|$ruDom)"
$isResearch = $taskLower -match "(?:research|docs|explore|analyze|$ruRes)"
$isQA = $taskLower -match "(?:test|pytest|vitest|qa|regression|security|$ruQA)"

# 2. Extract Memory Context Slice via PSScriptRoot
$memoryScript = Join-Path $PSScriptRoot "get-memory-brief.ps1"
if (-not (Test-Path $memoryScript)) {
    $memoryScript = Join-Path $repoRoot ".agents\scripts\get-memory-brief.ps1"
}
$memoryBrief = ""
if (Test-Path $memoryScript) {
    try {
        $memoryBrief = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $memoryScript -Query $Task -RootDir $repoRoot
    } catch {
        Write-Warning "Memory brief extraction failed: $($_.Exception.Message)"
        $memoryBrief = ""
    }
}

# 3. Assemble Tailored Subagents mapped to valid native TypeNames & 24 plugin agents
$swarm = @()

if ($isResearch) {
    $swarm += [PSCustomObject]@{
        Name = "explorer-agent"
        TypeName = "research"
        Role = "Deep Research & Documentation Scout"
        EnableWriteTools = $false
        EnableMCPTools = $true
        RecommendedMCPs = @("context7", "search_web")
        Model = "flash"
        Workspace = "inherit"
        InjectedRules = @(
            "Ban on full file reads >250 lines; targeted range reads only.",
            "Ponytail Restraint: Evaluate 7-Rung Ladder (YAGNI, Re-use), focus strictly on scoped requirements.",
            "Utilize context7 for library documentation and search_web for benchmarks.",
            "Read-only sandbox: zero code file mutations."
        )
        TaskSlice = "Investigate documentation, topology, and requirements for: $Task"
    }
}

if ($isDomain) {
    $swarm += [PSCustomObject]@{
        Name = "backend-specialist"
        TypeName = "self"
        Role = "Domain Logic & Business Services Architect"
        EnableWriteTools = $true
        EnableMCPTools = $false
        RecommendedMCPs = @()
        Model = "inherit"
        Workspace = "branch"
        InjectedRules = @(
            "Ponytail Restraint: Evaluate 7-Rung Ladder of Restraint before implementation (-40% to -50% code volume).",
            "Micro-modularity law: <=150 lines per file, <=30 lines per function.",
            "Strict typing and explicit interface/schema contracts.",
            "TDD Contract: write machine-checked tests before or with implementation.",
            "Adhere to domain contracts and invariants documented in memory/Index.md and memory/wiki/chapters/."
        )
        TaskSlice = "Implement domain services, data models, and unit/integration tests for: $Task"
    }
}

if ($isUI) {
    $swarm += [PSCustomObject]@{
        Name = "frontend-specialist"
        TypeName = "self"
        Role = "Production Frontend & Design System Specialist"
        EnableWriteTools = $true
        EnableMCPTools = $true
        RecommendedMCPs = @("chrome-devtools-mcp", "layout-math")
        Model = "inherit"
        Workspace = "branch"
        InjectedRules = @(
            "Ponytail Restraint: Evaluate 7-Rung Ladder of Restraint, -40% to -50% code volume.",
            "Follow active project design tokens and layout conventions from memory/Index.md and DESIGN.md.",
            "Anti-Slop UI (R-41): zero decorative crosses, zero fake APCA/WCAG badges or telemetry stamps.",
            "Responsive bounds: mobile (375px) and desktop (1440px) with accessible touch targets.",
            "Micro-modularity: component <=150 lines, extract reusable sub-components."
        )
        TaskSlice = "Implement reactive UI components, styles, and automated browser verification for: $Task"
    }
}

if ($swarm.Count -gt 0 -or $isQA) {
    $swarm += [PSCustomObject]@{
        Name = "test-engineer"
        TypeName = "self"
        Role = "Adversarial Code & Verification Harness Reviewer"
        EnableWriteTools = $true
        EnableMCPTools = $false
        RecommendedMCPs = @()
        Model = "inherit"
        Workspace = "inherit"
        InjectedRules = @(
            "Ponytail Restraint: Enforce 7-Rung Ladder of Restraint and anti-bloat during code review.",
            "Execute 4-stage verification harness (.agents/harness/run-harness.ps1).",
            "Zero empty catch/except blocks, zero speculative TODO comments.",
            "Enforce paired code and documentation updates in memory/wiki/.",
            "Adversarial verification of edge cases and regression risk."
        )
        TaskSlice = "Audit diff, run verification harness, and verify zero regressions for: $Task"
    }
}

if ($swarm.Count -eq 0) {
    $swarm += [PSCustomObject]@{
        Name = "orchestrator"
        TypeName = "self"
        Role = "Full-Stack Task Specialist"
        EnableWriteTools = $true
        EnableMCPTools = $true
        RecommendedMCPs = @("chrome-devtools-mcp", "context7")
        Model = "inherit"
        Workspace = "branch"
        InjectedRules = @(
            "Ponytail Restraint: 7-rung ladder, minimal code volume.",
            "Micro-modularity: files <=150 lines.",
            "Consult memory/Index.md for active invariants."
        )
        TaskSlice = "Execute task adhering to engineering protocol: $Task"
    }
}

# 4. Generate Execution DAG and Orchestration Plan
$dagSteps = @()
$dagSteps += "1. [Gate 0 Alignment]: Lead calls ask_question with 2-4 strategic options to align on approach."
$dagSteps += "2. [Dispatch Selection]: Reuse existing 24 agents with valid native TypeName (self / research) and Ponytail skill."
$dagSteps += "3. [Ponytail 7-Rung Restraint]: Evaluate Ladder of Restraint before code generation (-40% to -50% code volume)."

if ($swarm.Count -ge 2) {
    $workers = ($swarm | Where-Object { $_.Name -ne "test-engineer" }).Name -join " & "
    $dagSteps += "4. [Parallel Fan-Out]: Single-turn dispatch of [$workers] in isolated branch workspaces with Ponytail boundaries."
    $dagSteps += "5. [Synthesis]: Lead collects deliverables, verifies zero collisions, and prepares integration."
    $dagSteps += "6. [Adversarial Gate]: Dispatch test-engineer to execute verification harness and audit diff."
} else {
    $dagSteps += "4. [Single Worker Dispatch]: Dispatch $($swarm[0].Name) (TypeName: $($swarm[0].TypeName)) in isolated workspace with Ponytail boundaries."
    $dagSteps += "5. [Verification]: Run run-harness.ps1 to verify memory, code quality, and tests."
}
$dagSteps += "7. [Proof of Verification]: Present final AC Evidence Table to user."

$result = [PSCustomObject]@{
    Task = $Task
    Archetype = if ($swarm.Count -ge 3) { "T3_EPIC" } elseif ($swarm.Count -ge 2) { "T2_FEATURE" } else { "T1_HOTFIX" }
    SubagentsCount = $swarm.Count
    Swarm = $swarm
    ExecutionDAG = $dagSteps
    MemoryBriefLoaded = ($memoryBrief.Length -gt 0)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Just-In-Time (JIT) Swarm Assembly Plan  " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Task:             $Task" -ForegroundColor White
    Write-Host "Archetype:        $($result.Archetype)" -ForegroundColor Yellow
    Write-Host "Subagents Needed: $($swarm.Count) specialist roles" -ForegroundColor Green
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    foreach ($ag in $swarm) {
        Write-Host "`n[$($ag.Name)] (TypeName: $($ag.TypeName)) -> $($ag.Role)" -ForegroundColor Yellow
        Write-Host "  Model:       $($ag.Model) | Workspace: $($ag.Workspace)" -ForegroundColor Gray
        Write-Host "  Write Tools: $($ag.EnableWriteTools) | MCP Tools: $($ag.EnableMCPTools)" -ForegroundColor Cyan
        if ($ag.RecommendedMCPs.Count -gt 0) {
            Write-Host "  MCP Servers: $($ag.RecommendedMCPs -join ', ')" -ForegroundColor DarkCyan
        }
        Write-Host "  Injected Rules ($($ag.InjectedRules.Count)):" -ForegroundColor DarkGray
        foreach ($r in $ag.InjectedRules) {
            Write-Host "    - $r" -ForegroundColor DarkGray
        }
    }

    Write-Host "`n------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Execution Orchestration DAG:" -ForegroundColor Cyan
    foreach ($s in $dagSteps) {
        Write-Host "  $s" -ForegroundColor White
    }
    Write-Host "==========================================" -ForegroundColor Cyan
}
