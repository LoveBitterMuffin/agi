# assemble-swarm.ps1 - Just-In-Time (JIT) Swarm Assembler and Orchestration Engine
param(
    [Parameter(Mandatory=$true)]
    [string]$Task,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

$taskLower = $Task.ToLower()

# 1. Domain Detection
$isUI = $taskLower -match "(?:дизайн|ui|ux|css|стил|верстк|компонент|кнопк|виджет|палитр|модалк|страниц|анимаци|гексагон|хексагон|кабинет|карточк|landing|frontend)"
$isDomain = $taskLower -match "(?:сервис|auth|crm|рол|групп|оплат|payment|адаптер|модел|api|бэкенд|логик|homework|backend|service)"
$isResearch = $taskLower -match "(?:изучи|исследуй|документаци|moodle|аналог|конкурент|research|docs|найди)"
$isQA = $taskLower -match "(?:тест|test|vitest|проверь|аудит|qa|regression|security|регресс)"

# 2. Extract Memory Context Slice
$memoryScript = Join-Path $repoRoot ".agents\scripts\get-memory-brief.ps1"
$memoryBrief = ""
if (Test-Path $memoryScript) {
    try {
        $memoryBrief = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $memoryScript -Query $Task
    } catch {}
}

# 3. Assemble Tailored Subagents on the fly
$swarm = @()

if ($isResearch) {
    $swarm += [PSCustomObject]@{
        Name = "jit-scout"
        Role = "Deep Research & Documentation Scout"
        EnableWriteTools = $false
        EnableMCPTools = $true
        RecommendedMCPs = @("context7", "search_web")
        Model = "flash"
        Workspace = "inherit"
        InjectedRules = @(
            "Ban on full file reads >250 lines; targeted range reads only.",
            "Utilize context7 for library documentation and search_web for competitive benchmarks.",
            "Read-only sandbox: zero code file mutations."
        )
        TaskSlice = "Investigate documentation, topology, and requirements for: $Task"
    }
}

if ($isDomain) {
    $swarm += [PSCustomObject]@{
        Name = "jit-domain-engineer"
        Role = "Domain Logic & Business Services Architect"
        EnableWriteTools = $true
        EnableMCPTools = $false
        RecommendedMCPs = @()
        Model = "inherit"
        Workspace = "branch"
        InjectedRules = @(
            "Micro-modularity law: <=150 lines per file, <=30 lines per function.",
            "Strict TypeScript typing: no untyped 'any', explicit interface contracts.",
            "TDD Contract: write machine-checked tests in tests/ before or with implementation.",
            "Adhere to domain contracts from memory/wiki/chapters/011_domain_models_and_services.md."
        )
        TaskSlice = "Implement domain services, data models, and Vitest test suite for: $Task"
    }
}

if ($isUI) {
    $swarm += [PSCustomObject]@{
        Name = "jit-ui-craftsman"
        Role = "Production Frontend & Design System Specialist"
        EnableWriteTools = $true
        EnableMCPTools = $true
        RecommendedMCPs = @("chrome-devtools-mcp", "layout-math")
        Model = "inherit"
        Workspace = "branch"
        InjectedRules = @(
            "Hexagonal design system tokens: sapphire blue palette, clip-hexagon, 8pt spatial grid.",
            "Anti-Slop UI: zero decorative crosses (+, +), zero fake badges (APCA AAA PASS).",
            "Responsive bounds: mobile (375px) and desktop (1440px) with minimum 44px touch targets.",
            "Micro-modularity: component <=150 lines, extract reusable sub-components."
        )
        TaskSlice = "Implement reactive UI components, styles, and automated browser verification for: $Task"
    }
}

# Always attach QA Reviewer for multi-file or critical tasks
if ($swarm.Count -gt 0 -or $isQA) {
    $swarm += [PSCustomObject]@{
        Name = "jit-qa-reviewer"
        Role = "Adversarial Code & Verification Harness Reviewer"
        EnableWriteTools = $true
        EnableMCPTools = $false
        RecommendedMCPs = @()
        Model = "inherit"
        Workspace = "inherit"
        InjectedRules = @(
            "Execute 4-stage verification harness (.agents/harness/run-harness.ps1).",
            "Zero empty catch/except blocks, zero speculative TODO comments.",
            "Enforce paired code and documentation updates in memory/wiki/.",
            "Adversarial verification of edge cases, regression risk, and touch targets."
        )
        TaskSlice = "Audit diff, run 4-stage harness, and verify zero regressions for: $Task"
    }
}

# Default fallback if task is general
if ($swarm.Count -eq 0) {
    $swarm += [PSCustomObject]@{
        Name = "jit-general-worker"
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
$dagSteps += "2. [JIT Registration]: Register tailor-made subagents via define_subagent with injected rules and tools."

if ($swarm.Count -ge 2) {
    $workers = ($swarm | Where-Object { $_.Name -ne "jit-qa-reviewer" }).Name -join " & "
    $dagSteps += "3. [Parallel Fan-Out]: Single-turn dispatch of [$workers] in isolated branch workspaces."
    $dagSteps += "4. [Synthesis]: Lead collects deliverables, verifies zero collisions, and prepares integration."
    $dagSteps += "5. [Adversarial Gate]: Dispatch jit-qa-reviewer to execute 4-stage harness and audit diff."
} else {
    $dagSteps += "3. [Single Worker Dispatch]: Dispatch $($swarm[0].Name) in isolated workspace."
    $dagSteps += "4. [Verification]: Run run-harness.ps1 to verify memory, code quality, and tests."
}
$dagSteps += "6. [Proof of Verification]: Present final AC Evidence Table to user."

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
    Write-Host "Subagents Needed: $($swarm.Count) tailor-made roles" -ForegroundColor Green
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    foreach ($ag in $swarm) {
        Write-Host "`n[$($ag.Name)] -> $($ag.Role)" -ForegroundColor Yellow
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
