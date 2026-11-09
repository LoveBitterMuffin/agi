# ATRUS: Adaptive Teleport Router & User Inquiry System
[CmdletBinding()]
param(
    [string]$Prompt = "",
    [int]$TargetPhase = 0,
    [int]$CurrentPhase = 1,
    [switch]$HarnessPassed
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Detect-TeleportIntent([string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) {
        return @{ Intent = "NONE"; Target = 0; Reason = "Empty prompt." }
    }
    $lower = $text.ToLower()
    if ($lower -match "reset|start over|restart|сначала|заново|сброс|отмени") {
        return @{ Intent = "RESET_TO_START"; Target = 1; Reason = "User requested reset to start." }
    }
    if ($lower -match "memory|brief|выжимк|памят|бриф|индекс|контекст") {
        return @{ Intent = "JUMP_TO_MEMORY"; Target = 1; Reason = "Memory extraction or brief requested." }
    }
    if ($lower -match "run tests|run harness|audit|test|проверь|протестируй|запусти тесты|тест|аудит") {
        return @{ Intent = "JUMP_TO_HARNESS"; Target = 7; Reason = "Direct testing or audit requested." }
    }
    if ($lower -match "spec|rfc|architecture|design|спецификац|спеку|архитектур|дизайн[- ]систему|спроектируй") {
        return @{ Intent = "JUMP_TO_SPEC"; Target = 2; Reason = "Design / Specification task detected." }
    }
    if ($lower -match "swarm|subagent|parallel|субагент|рой|делегируй|воркер") {
        return @{ Intent = "JUMP_TO_SWARM"; Target = 6; Reason = "Parallel subagent swarm requested." }
    }
    if ($lower -match "obsidian|sync|canvas|release|обсидиан|синхрониз|холст|релиз") {
        return @{ Intent = "JUMP_TO_SYNC"; Target = 8; Reason = "Obsidian memory sync requested." }
    }
    return @{ Intent = "AMBIGUOUS"; Target = 0; Reason = "Ambiguous intent." }
}

function Resolve-SkippedPhases([int]$fromP, [int]$toP) {
    $skipped = @()
    if ($toP -gt $fromP + 1) {
        for ($i = $fromP + 1; $i -lt $toP; $i++) { $skipped += $i }
    }
    return $skipped
}

function Validate-Invariants([int]$target, [bool]$passed) {
    if ($target -eq 8 -and -not $passed) {
        return @{
            Valid = $false
            Redirect = 7
            Reason = "INV-01 Violation: Teleport to Phase 8 blocked. Phase 7 Harness must pass first."
        }
    }
    return @{ Valid = $true; Redirect = $target; Reason = "Invariants satisfied." }
}

$detection = Detect-TeleportIntent $Prompt
$resolvedTarget = if ($TargetPhase -gt 0) { $TargetPhase } else { $detection.Target }

if ($resolvedTarget -eq 0) {
    $result = [PSCustomObject]@{
        TeleportGranted = $false
        TargetPhase = 1
        NeedsSurvey = $true
        SurveyQuestion = "Select teleport destination or resume sequential pipeline:"
        SurveyOptions = @(
            "(Recommended) Continue default pipeline (Phase 1 -> 8)",
            "Reset to start (Phase 1: Reset)",
            "Jump directly to verification (Phase 7: 4-Stage Harness)"
        )
        Reason = "No explicit phase target detected."
    }
    $result | ConvertTo-Json -Depth 3
    exit 0
}

$check = Validate-Invariants $resolvedTarget $HarnessPassed.IsPresent
$finalTarget = $check.Redirect
$skipped = Resolve-SkippedPhases $CurrentPhase $finalTarget

$result = [PSCustomObject]@{
    TeleportGranted = $check.Valid
    FromPhase = $CurrentPhase
    TargetPhase = $finalTarget
    SkippedPhases = $skipped
    NeedsSurvey = $false
    Reason = if ($check.Valid) { $detection.Reason } else { $check.Reason }
    InvariantBlocked = (-not $check.Valid)
}

$result | ConvertTo-Json -Depth 3
