# triage-task.ps1 - Adaptive Entrypoint Dispatcher & Archetype Classifier
param(
    [Parameter(Mandatory=$true)]
    [string]$Task,

    [int]$FilesCount = 0,
    [switch]$IsArchitectural,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

$taskLower = $Task.ToLower().Trim()

# 1. Question vs Mutating Detection (Bilingual EN/RU via pure-ASCII escapes)
$ruQ = [regex]::Unescape('\u0433\u0434\u0435|\u0447\u0442\u043e|\u043a\u0430\u043a|\u043f\u043e\u0447\u0435\u043c\u0443|\u043a\u0442\u043e|\u043e\u0431\u044a\u044f\u0441\u043d\u0438|\u0441\u0442\u0430\u0442\u0443\u0441|\u043e\u043f\u0438\u0448\u0438|\u043f\u043e\u043a\u0430\u0436\u0438|\u0441\u043f\u0438\u0441\u043e\u043a|\u0440\u0430\u0441\u0441\u043a\u0430\u0436\u0438|\u0431\u0443\u0434\u0435\u0442 \u043b\u0438|\u0441\u043a\u0430\u0436\u0438')
$ruMut = [regex]::Unescape('\u0441\u043e\u0437\u0434\u0430\u0439|\u0441\u043e\u0437\u0434\u0430\u0434\u0438\u043c|\u0434\u043e\u0431\u0430\u0432\u044c|\u0434\u043e\u0431\u0430\u0432\u0438\u043c|\u043f\u043e\u0434\u043a\u043b\u044e\u0447\u0438|\u043f\u043e\u0434\u043a\u043b\u044e\u0447\u0438\u043c|\u0441\u0434\u0435\u043b\u0430\u0439|\u0438\u0441\u043f\u0440\u0430\u0432\u044c|\u043f\u043e\u0447\u0438\u043d\u0438|\u043f\u043e\u043f\u0440\u0430\u0432\u044c|\u043f\u0435\u0440\u0435\u043f\u0438\u0448\u0438|\u0443\u0434\u0430\u043b\u0438|\u043e\u0431\u043d\u043e\u0432\u0438|\u0434\u043e\u043f\u0438\u0448\u0438|\u043e\u043f\u0442\u0438\u043c\u0438\u0437\u0438\u0440\u0443\u0439|\u043d\u0430\u0441\u0442\u0440\u043e\u0439|\u043d\u0430\u0441\u0442\u0440\u043e\u0438\u043c|\u0432\u043d\u0435\u0434\u0440\u0438|\u0432\u043d\u0435\u0434\u0440\u0438\u0442\u044c')

$questionPattern = "^(?:where|what|how|why|who|explain|status|describe|show|list|tell|$ruQ)\b"
$mutatingPattern = "(?:fix|patch|build|implement|create|refactor|migration|delete|update|add|connect|setup|$ruMut)"

$isQuestion = $taskLower -match $questionPattern
$isMutating = $taskLower -match $mutatingPattern

# 2. Domain & Complexity Patterns
$ruEpic = [regex]::Unescape('\u0434\u0438\u0437\u0430\u0439\u043d[- ]\u0441\u0438\u0441\u0442\u0435\u043c\u0443|\u0434\u0438\u0437\u0430\u0439\u043d|\u0430\u0440\u0445\u0438\u0442\u0435\u043a\u0442\u0443\u0440|\u0441 \u043d\u0443\u043b\u044f|\u043f\u043e\u043b\u043d\u043e\u0441\u0442\u044c\u044e|\u0440\u0435\u0434\u0438\u0437\u0430\u0439\u043d|\u043c\u0438\u0433\u0440\u0430\u0446\u0438|\u043f\u0435\u0440\u0435\u043f\u0438\u0441\u0430\u0442\u044c|\u043f\u043b\u0430\u0442\u0444\u043e\u0440\u043c|\u0434\u0432\u0443\u0445\u0441\u043b\u043e\u0439\u043d|\u043c\u043d\u043e\u0433\u043e\u0430\u0433\u0435\u043d\u0442\u043d')
$ruFeat = [regex]::Unescape('\u0444\u0438\u0447|\u0434\u043e\u0431\u0430\u0432\u044c|\u0434\u043e\u0431\u0430\u0432\u0438\u043c|\u0440\u0435\u0430\u043b\u0438\u0437\u0443\u0439|\u0441\u043e\u0437\u0434\u0430\u0439|\u043f\u043e\u0434\u043a\u043b\u044e\u0447\u0438|\u0440\u0435\u0433\u0438\u0441\u0442\u0440\u0430\u0446\u0438|\u043e\u043f\u043b\u0430\u0442|\u0440\u043e\u043b\u0438|\u0430\u0434\u0430\u043f\u0442\u0435\u0440|\u0441\u0442\u0440\u0430\u043d\u0438\u0446\u0443|\u043a\u043e\u043c\u043f\u043e\u043d\u0435\u043d\u0442|\u0432\u0438\u0434\u0436\u0435\u0442|\u0441\u0435\u0440\u0432\u0438\u0441')
$ruHot = [regex]::Unescape('\u043c\u0435\u0434\u043b\u0435\u043d\u043d?\u0435[\u0435\u0439]|\u0431\u044b\u0441\u0442\u0440\u0435\u0435|\u043f\u043e\u043f\u0440\u0430\u0432\u044c|\u043e\u043f\u0435\u0447\u0430\u0442\u043a|\u043f\u043e\u0447\u0438\u043d\u0438|\u0438\u0441\u043f\u0440\u0430\u0432\u044c \u0431\u0430\u0433|\u043f\u043e\u0434\u043f\u0440\u0430\u0432\u044c|\u043f\u043e\u043c\u0435\u043d\u044f\u0439 \u0446\u0432\u0435\u0442|\u0442\u0430\u0439\u043c\u0430\u0443\u0442')

$epicPattern = "(?:migration|refactor|architecture|greenfield|epic|redesign|from scratch|$ruEpic)"
$featurePattern = "(?:feature|implement|add component|create module|new system|build|crm|$ruFeat)"
$hotfixPattern = "(?:fast|patch|hotfix|typo|update|config|quick|fix|repair|edit|$ruHot)"

# 3. Classify Archetype
if ($isQuestion -and -not $isMutating -and ($FilesCount -le 0) -and -not $IsArchitectural) {
    $archetype = "T0_INSTANT"
    $title = "Zero-Tool Query / Advisory"
    $flow = "Fast-Path (Direct main thread response, zero ceremonies)"
    $specGate = "None"
    $subagents = "None"
    $tokenBudget = "< 1,000 tokens"
    $modelTier = "flash_lite / instant"
}
elseif ($IsArchitectural -or ($FilesCount -gt 5) -or ($taskLower -match $epicPattern)) {
    $archetype = "T3_EPIC"
    $title = "Architectural Epic / System Redesign"
    $flow = "Dual-Loop Reflexive Pipeline (Gate 0 Inquiry -> Spec Gate -> Swarm Fan-Out -> Release Audit)"
    $specGate = "Hard Gate (Gate 0 ask_question + SPEC-YYYY-NNN Sign-off)"
    $subagents = "Full Swarm Mesh (Color, UX, UI, Coder in branch, Security Auditor)"
    $tokenBudget = "20,000 - 40,000 tokens (isolated in branch)"
    $modelTier = "pro / coordinator"
}
elseif (($FilesCount -ge 2) -or ($taskLower -match $featurePattern)) {
    $archetype = "T2_FEATURE"
    $title = "Greenfield Feature / Subsystem Slice"
    $flow = "Spec-First Swarm Pipeline (Gate 0 Inquiry -> Spec Gate -> Subagent Swarm -> Demo)"
    $specGate = "Mandatory Gate 0 + AC Matrix (SPEC-YYYY-NNN)"
    $subagents = "Parallel Subagent Swarm (TypeName: self in branch, test-engineer, security-auditor)"
    $tokenBudget = "8,000 - 15,000 tokens"
    $modelTier = "inherit (flash/standard)"
}
elseif ($isMutating -or ($FilesCount -eq 1) -or ($taskLower -match $hotfixPattern)) {
    $archetype = "T1_HOTFIX"
    $title = "Targeted Atomic Patch / Hotfix"
    $flow = "Targeted Atomic Path (Ponytail Restraint -> Edit -> 1 Targeted Test)"
    $specGate = "Lightweight (Inline verification, no formal spec)"
    $subagents = "None or 1 Subagent (TypeName: self)"
    $tokenBudget = "1,500 - 3,000 tokens"
    $modelTier = "flash / fast"
}
else {
    $archetype = "T0_INSTANT"
    $title = "Zero-Tool Query / Advisory"
    $flow = "Fast-Path (Direct main thread response, zero ceremonies)"
    $specGate = "None"
    $subagents = "None"
    $tokenBudget = "< 1,000 tokens"
    $modelTier = "flash_lite / instant"
}

$result = [PSCustomObject]@{
    Task = $Task
    Archetype = $archetype
    Title = $title
    ExecutionFlow = $flow
    SpecGate = $specGate
    Subagents = $subagents
    TokenBudget = $tokenBudget
    ModelTier = $modelTier
}

if ($Json) {
    $result | ConvertTo-Json -Compress
} else {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Entrypoint Triage and Dispatch Pipeline " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Task:        $Task" -ForegroundColor White
    Write-Host "Archetype:   [$archetype] $title" -ForegroundColor Yellow
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Pipeline:    $flow" -ForegroundColor White
    Write-Host "Spec Gate:   $specGate" -ForegroundColor $(if ($specGate -match "Hard") { "Red" } elseif ($specGate -match "Mandatory") { "Yellow" } else { "Green" })
    Write-Host "Subagents:   $subagents" -ForegroundColor White
    Write-Host "Budget:      $tokenBudget" -ForegroundColor Cyan
    Write-Host "Model:       $modelTier" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Cyan
}
