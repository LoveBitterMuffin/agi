# ATRUS: Adaptive Teleport Router & User Inquiry System
[CmdletBinding()]
param(
    [string]$Prompt = "",
    [int]$TargetPhase = 0,
    [int]$CurrentPhase = 1,
    [switch]$HarnessPassed
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

function Detect-TeleportIntent([string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) {
        return @{ Intent = "NONE"; Target = 0; Command = ""; Reason = "Empty prompt." }
    }
    $lower = $text.ToLower()

    $ruReset = [regex]::Unescape('\u0441\u043d\u0430\u0447\u0430\u043b\u0430|\u0437\u0430\u043d\u043e\u0432\u043e|\u0441\u0431\u0440\u043e\u0441|\u043e\u0442\u043c\u0435\u043d\u0438')
    $ruMem = [regex]::Unescape('\u0432\u044b\u0436\u0438\u043c\u043a|\u043f\u0430\u043c\u044f\u0442|\u0431\u0440\u0438\u0444|\u0438\u043d\u0434\u0435\u043a\u0441|\u043a\u043e\u043d\u0442\u0435\u043a\u0441\u0442')
    $ruRel = [regex]::Unescape('\u0440\u0435\u043b\u0438\u0437')
    $ruHar = [regex]::Unescape('\u043f\u0440\u043e\u0432\u0435\u0440\u044c|\u043f\u0440\u043e\u0442\u0435\u0441\u0442\u0438\u0440\u0443\u0439|\u0437\u0430\u043f\u0443\u0441\u0442\u0438 \u0442\u0435\u0441\u0442\u044b|\u0442\u0435\u0441\u0442|\u0430\u0443\u0434\u0438\u0442')
    $ruSpec = [regex]::Unescape('\u0441\u043f\u0435\u0446\u0438\u0444\u0438\u043a\u0430\u0446|\u0441\u043f\u0435\u043a\u0443|\u0430\u0440\u0445\u0438\u0442\u0435\u043a\u0442\u0443\u0440|\u0434\u0438\u0437\u0430\u0439\u043d[- ]\u0441\u0438\u0441\u0442\u0435\u043c\u0443|\u0441\u043f\u0440\u043e\u0435\u043a\u0442\u0438\u0440\u0443\u0439')
    $ruSwarm = [regex]::Unescape('\u0441\u0443\u0431\u0430\u0433\u0435\u043d\u0442|\u0440\u043e\u0439|\u0434\u0435\u043b\u0435\u0433\u0438\u0440\u0443\u0439|\u0432\u043e\u0440\u043a\u0435\u0440')
    $ruSync = [regex]::Unescape('\u043e\u0431\u0441\u0438\u0434\u0438\u0430\u043d|\u0441\u0438\u043d\u0445\u0440\u043e\u043d\u0438\u0437|\u0445\u043e\u043b\u0441\u0442')

    if ($lower -match "reset|start over|restart|$ruReset") {
        return @{ Intent = "RESET_TO_START"; Target = 1; Command = "/wiki-brief"; Reason = "User requested reset to start." }
    }
    if ($lower -match "memory|brief|$ruMem") {
        return @{ Intent = "JUMP_TO_MEMORY"; Target = 1; Command = "/wiki-brief"; Reason = "Memory extraction or brief requested." }
    }
    if ($lower -match "release-audit|release|$ruRel") {
        return @{ Intent = "JUMP_TO_RELEASE_AUDIT"; Target = 8; Command = "/release-audit"; Reason = "Release audit (/release-audit) requested." }
    }
    if ($lower -match "run tests|run harness|audit|test|$ruHar") {
        return @{ Intent = "JUMP_TO_HARNESS"; Target = 7; Command = "/verify"; Reason = "Direct testing or audit requested." }
    }
    if ($lower -match "spec|rfc|architecture|design|$ruSpec") {
        return @{ Intent = "JUMP_TO_SPEC"; Target = 2; Command = "/plan"; Reason = "Design / Specification task detected." }
    }
    if ($lower -match "swarm|subagent|parallel|$ruSwarm") {
        return @{ Intent = "JUMP_TO_SWARM"; Target = 6; Command = "/coordinate"; Reason = "Parallel subagent swarm requested." }
    }
    if ($lower -match "obsidian|sync|canvas|$ruSync") {
        return @{ Intent = "JUMP_TO_SYNC"; Target = 8; Command = "sync-obsidian.ps1"; Reason = "Obsidian memory sync requested." }
    }
    return @{ Intent = "AMBIGUOUS"; Target = 0; Command = ""; Reason = "Ambiguous intent." }
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
        Intent = $detection.Intent
        Command = ""
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
    Intent = $detection.Intent
    Command = $detection.Command
    Reason = if ($check.Valid) { $detection.Reason } else { $check.Reason }
    InvariantBlocked = (-not $check.Valid)
}

$result | ConvertTo-Json -Depth 3
