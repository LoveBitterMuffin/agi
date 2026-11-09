# init-spec.ps1 - Automated Spec-First & TERA Scaffold Initializer
param(
    [Parameter(Mandatory=$true)]
    [string]$FeatureName,
    [int]$EstimatedFiles = 2,
    [switch]$IsArchitectural,
    [switch]$HasExternalAPIs
)

$ErrorActionPreference = "Stop"

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

$currentYear = (Get-Date).ToString("yyyy")
$inboxDir = Join-Path $repoRoot "memory\raw\inbox"
$vaultDir = Join-Path $repoRoot "memory\raw\vault"

# 1. Determine Next Spec ID
$existingSpecs = @(Get-ChildItem -Path $inboxDir, $vaultDir -Filter "*SPEC-$currentYear-*.md" -ErrorAction SilentlyContinue)
$maxSeq = 0
foreach ($s in $existingSpecs) {
    if ($s.Name -match "(?:RAW-)?SPEC-$currentYear-([0-9]{3})_") {
        $num = [int]$matches[1]
        if ($num -gt $maxSeq) { $maxSeq = $num }
    }
}
$nextSeq = "{0:D3}" -f ($maxSeq + 1)
$specId = "SPEC-$currentYear-$nextSeq"
$cleanSlug = ($FeatureName -replace '[^a-zA-Z0-9_\-]', '-').ToLower()
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
$templatePath = Join-Path $PSScriptRoot "..\templates\SPEC_TEMPLATE.md"
$templateContent = Get-Content $templatePath -Raw

$specContent = $templateContent -replace '\[Feature Name\]', $FeatureName
$specContent = $specContent -replace 'SPEC-YYYY-NNN', $specId
$specContent = $specContent -replace '\[Draft / Approved / In-Progress / Completed\]', "Draft (TERA $($teraJson.TierCode): $($teraJson.Tier))"

# Prepend TERA Allocation Metadata
$teraBlock = @"
> **TERA Complexity Score:** $($teraJson.ComplexityScore) / 12 ($($teraJson.Tier))  
> **Recommended Model:** $($teraJson.RecommendedModel)  
> **Token Budget:** $($teraJson.TokenBudget)  
> **Assigned Subagent Swarm:** $($teraJson.AllocatedSubagents -join ', ')  
> **Worktree Isolation:** $(if ($teraJson.WorktreeRequired) { 'Required' } else { 'Standard Workspace' })  

"@
$specContent = [regex]::Replace($specContent, '(?m)^---$', "---`n`n$teraBlock", 1)

Set-Content -Path $targetPath -Value $specContent -Encoding UTF8

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Spec-First Initializer Complete         " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Spec Document: $targetPath" -ForegroundColor Green
Write-Host "Complexity:    $($teraJson.Tier) (Score: $($teraJson.ComplexityScore))" -ForegroundColor Yellow
Write-Host "Swarm:         $($teraJson.AllocatedSubagents -join ', ')" -ForegroundColor White
Write-Host "`nNext Step: Run interactive clarification via ask_question with user." -ForegroundColor Cyan
