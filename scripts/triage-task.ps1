# triage-task.ps1 - Adaptive Entrypoint Dispatcher & Archetype Classifier
param(
    [Parameter(Mandatory=$true)]
    [string]$Task,

    [int]$FilesCount = 0,
    [switch]$IsArchitectural,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$taskLower = $Task.ToLower().Trim()

# 1. Question vs Mutating Detection (Bilingual EN/RU)
$questionPattern = "^(?:where|what|how|why|who|explain|status|describe|show|list|tell|где|что|как|почему|кто|объясни|статус|опиши|покажи|список|расскажи|будет ли|скажи)\b"
$mutatingPattern = "(?:fix|patch|build|implement|create|refactor|migration|delete|update|add|connect|setup|создай|создадим|добавь|добавим|подключи|подключим|сделай|исправь|перепиши|удали|обнови|настрой|настроим|внедри|внедрить)"

$isQuestion = $taskLower -match $questionPattern
$isMutating = $taskLower -match $mutatingPattern

# 2. Domain & Complexity Patterns
$epicPattern = "(?:migration|refactor|architecture|greenfield|epic|redesign|from scratch|дизайн[- ]систему|дизайн|архитектур|с нуля|полностью|редизайн|миграци|переписать|платформ|двухслойн|многоагентн)"
$featurePattern = "(?:feature|implement|add component|create module|new system|build|фич|добавь|добавим|реализуй|создай|подключи|регистраци|оплат|crm|роли|адаптер|страницу|компонент|виджет|сервис)"
$hotfixPattern = "(?:fast|patch|hotfix|typo|update|config|quick|fix|repair|edit|медленн?е[ей]|быстрее|поправь|опечатк|почини|исправь баг|подправь|поменяй цвет|таймаут)"

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
    $subagents = "Full Swarm Mesh (Color, UX, UI, Coder in branch, Reviewer)"
    $tokenBudget = "20,000 - 40,000 tokens (isolated in branch)"
    $modelTier = "pro / coordinator"
}
elseif (($FilesCount -ge 2) -or ($taskLower -match $featurePattern)) {
    $archetype = "T2_FEATURE"
    $title = "Greenfield Feature / Subsystem Slice"
    $flow = "Spec-First Swarm Pipeline (Gate 0 Inquiry -> Spec Gate -> Subagent Swarm -> Demo)"
    $specGate = "Mandatory Gate 0 + AC Matrix (SPEC-YYYY-NNN)"
    $subagents = "Parallel Subagent Swarm (Role: Coder in branch, QA, Reviewer)"
    $tokenBudget = "8,000 - 15,000 tokens"
    $modelTier = "inherit (flash/standard)"
}
elseif ($isMutating -or ($FilesCount -eq 1) -or ($taskLower -match $hotfixPattern)) {
    $archetype = "T1_HOTFIX"
    $title = "Targeted Atomic Patch / Hotfix"
    $flow = "Targeted Atomic Path (PonyTail Restraint -> Edit -> 1 Targeted Test)"
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
