# init-spec.ps1 - Automated Spec-First & TERA Scaffold Initializer
param(
    [Parameter(Mandatory=$true)]
    [string]$FeatureName,
    [int]$EstimatedFiles = 2,
    [switch]$IsArchitectural,
    [switch]$HasExternalAPIs,
    [string]$RootDir = ""
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

function ConvertTo-AsciiSlug {
    param([string]$Text, [string]$Fallback = "spec")
    $map = @{
        [char]0x0430 = "a";  [char]0x0431 = "b";  [char]0x0432 = "v";  [char]0x0433 = "g"
        [char]0x0434 = "d";  [char]0x0435 = "e";  [char]0x0451 = "yo"; [char]0x0436 = "zh"
        [char]0x0437 = "z";  [char]0x0438 = "i";  [char]0x0439 = "y";  [char]0x043A = "k"
        [char]0x043B = "l";  [char]0x043C = "m";  [char]0x043D = "n";  [char]0x043E = "o"
        [char]0x043F = "p";  [char]0x0440 = "r";  [char]0x0441 = "s";  [char]0x0442 = "t"
        [char]0x0443 = "u";  [char]0x0444 = "f";  [char]0x0445 = "kh"; [char]0x0446 = "ts"
        [char]0x0447 = "ch"; [char]0x0448 = "sh"; [char]0x0449 = "shch"; [char]0x044A = ""
        [char]0x044B = "y";  [char]0x044C = "";   [char]0x044D = "e";  [char]0x044E = "yu"
        [char]0x044F = "ya"
    }
    $sb = [System.Text.StringBuilder]::new()
    foreach ($ch in $Text.ToLowerInvariant().ToCharArray()) {
        if ($map.ContainsKey($ch)) { [void]$sb.Append($map[$ch]) }
        else { [void]$sb.Append($ch) }
    }
    $slug = ($sb.ToString() -replace '[^a-z0-9_\-]', '-' -replace '-{2,}', '-').Trim('-', '_')
    if (-not $slug) { return $Fallback }
    return $slug
}

if ($RootDir) {
    $repoRoot = [System.IO.Path]::GetFullPath($RootDir)
} else {
    $cwd = (Get-Location).ProviderPath
    $gitTop = (git -C $cwd rev-parse --show-toplevel 2>$null)
    $homeNorm = [System.IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
    $cwdNorm = [System.IO.Path]::GetFullPath($cwd).TrimEnd('\', '/')
    $repoRoot = if ($gitTop -and ([System.IO.Path]::GetFullPath($gitTop).TrimEnd('\', '/') -ne $homeNorm -or $cwdNorm -eq $homeNorm)) { $gitTop } else { $cwd }
}

$currentYear = (Get-Date).ToString("yyyy")
$inboxDir = Join-Path $repoRoot "memory\raw\inbox"
$vaultDir = Join-Path $repoRoot "memory\raw\vault"
if (-not (Test-Path $inboxDir)) { New-Item -ItemType Directory -Path $inboxDir -Force | Out-Null }

# 1. Determine Next Spec ID
$existingSpecs = @(Get-ChildItem -Path @($inboxDir, $vaultDir) -Filter "*SPEC-$currentYear-*.md" -ErrorAction SilentlyContinue)
$maxSeq = 0
foreach ($s in $existingSpecs) {
    if ($s.Name -match "(?:RAW-)?SPEC-$currentYear-([0-9]{3})_") {
        $num = [int]$matches[1]
        if ($num -gt $maxSeq) { $maxSeq = $num }
    }
}
$nextSeq = "{0:D3}" -f ($maxSeq + 1)
$specId = "SPEC-$currentYear-$nextSeq"
$cleanSlug = ConvertTo-AsciiSlug -Text $FeatureName -Fallback "spec"
$targetFileName = "$specId`_$cleanSlug.md"
$targetPath = Join-Path $inboxDir $targetFileName

# 2. Run TERA Complexity Estimation
$teraScript = Join-Path $PSScriptRoot "estimate-complexity.ps1"
$teraJson = & $teraScript `
    -Description $FeatureName `
    -EstimatedFiles $EstimatedFiles `
    -IsArchitectural:$IsArchitectural `
    -HasExternalAPIs:$HasExternalAPIs `
    -JsonOutput | ConvertFrom-Json

# 3. Read Template & Fill Stubs
$templateCandidates = @(
    (Join-Path $PSScriptRoot "..\templates\SPEC_TEMPLATE.md"),
    (Join-Path $repoRoot ".agents\templates\SPEC_TEMPLATE.md")
)
$templatePath = $templateCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($templatePath) {
    $templateContent = Get-Content $templatePath -Raw -Encoding UTF8
} else {
    $templateContent = @"
# Specification: [Feature Name]

**Spec ID:** SPEC-YYYY-NNN  
**Status:** [Draft / Approved / In-Progress / Completed]  
**Target Chapter:** ``memory/wiki/chapters/000_overview.md``  
**Target SemVer:** PATCH  

---

## 1. Overview & Scope
Concise description of the target behavior, subsystem boundaries, and invariants.

## 2. Requirements

### Requirement: Core Behavior
The system SHALL implement the requested capability.

## 3. Acceptance Criteria

| ID | Criterion | Verification Method |
| :--- | :--- | :--- |
| **AC-01** | `<measurable requirement>` | `<pytest / harness check>` |
"@
}

$specContent = $templateContent -replace '\[Feature Name\]', $FeatureName
$specContent = $specContent -replace 'SPEC-YYYY-NNN', $specId
$specContent = $specContent -replace '\[Draft / Approved / In-Progress / Completed\]', "Draft (TERA $($teraJson.TierCode): $($teraJson.Tier))"

$teraBlock = @"
> **TERA Complexity Score:** $($teraJson.ComplexityScore) / 12 ($($teraJson.Tier))  
> **Recommended Model:** $($teraJson.RecommendedModel)  
> **Token Budget:** $($teraJson.TokenBudget)  
> **Assigned Subagent Swarm:** $($teraJson.AllocatedSubagents -join ', ')  
> **Worktree Isolation:** $(if ($teraJson.WorktreeRequired) { 'Required' } else { 'Standard Workspace' })  

"@
$specContent = [regex]::Replace($specContent, '(?m)^---$', "---`n`n$teraBlock", 1)

[System.IO.File]::WriteAllText($targetPath, $specContent, $utf8NoBom)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Spec-First Initializer Complete         " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Spec Document: $targetPath" -ForegroundColor Green
Write-Host "Complexity:    $($teraJson.Tier) (Score: $($teraJson.ComplexityScore))" -ForegroundColor Yellow
Write-Host "Swarm:         $($teraJson.AllocatedSubagents -join ', ')" -ForegroundColor White
Write-Host "`nNext Step: Run interactive clarification via ask_question with user." -ForegroundColor Cyan
