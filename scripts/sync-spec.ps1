# sync-spec.ps1 - OpenSpec Delta-to-Main Spec Synchronizer & Vault Archiver
param(
    [Parameter(Mandatory=$true)]
    [string]$SpecFile,

    [string]$TargetChapter = "",
    [ValidateSet("PATCH", "MINOR", "MAJOR")]
    [string]$BumpType = "",
    [string]$RootDir = ""
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  OpenSpec Delta-to-Main Synchronizer     " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if ($RootDir) {
    $repoRoot = [System.IO.Path]::GetFullPath($RootDir)
} else {
    $cwd = (Get-Location).ProviderPath
    $gitTop = (git -C $cwd rev-parse --show-toplevel 2>$null)
    $homeNorm = [System.IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
    $cwdNorm = [System.IO.Path]::GetFullPath($cwd).TrimEnd('\', '/')
    $repoRoot = if ($gitTop -and ([System.IO.Path]::GetFullPath($gitTop).TrimEnd('\', '/') -ne $homeNorm -or $cwdNorm -eq $homeNorm)) { $gitTop } else { $cwd }
}

# 1. Resolve SpecFile
$resolvedSpecPath = $SpecFile
if (-not [System.IO.Path]::IsPathRooted($resolvedSpecPath)) {
    $resolvedSpecPath = Join-Path $repoRoot $SpecFile
}

if (-not (Test-Path $resolvedSpecPath)) {
    Write-Host "[FAIL] Spec file not found at: $resolvedSpecPath" -ForegroundColor Red
    exit 1
}

$specContent = [System.IO.File]::ReadAllText($resolvedSpecPath, $utf8NoBom)
$specFileName = Split-Path -Leaf $resolvedSpecPath

# 2. Extract Metadata from Spec Header
if ($specContent -match '(?m)^\*\*Target Chapter:\*\*\s*`?([^`\r\n]+)`?') {
    if (-not $TargetChapter) { $TargetChapter = $matches[1].Trim() }
}
if ($specContent -match '(?m)^\*\*Target SemVer:\*\*\s*([A-Z]+)') {
    if (-not $BumpType) { $BumpType = $matches[1].Trim() }
}

if (-not $TargetChapter) {
    Write-Host "[FAIL] Target chapter not specified in spec header and not passed via -TargetChapter." -ForegroundColor Red
    exit 1
}
if (-not $BumpType) { $BumpType = "PATCH" }

$resolvedChapterPath = $TargetChapter
if (-not [System.IO.Path]::IsPathRooted($resolvedChapterPath)) {
    $resolvedChapterPath = Join-Path $repoRoot $TargetChapter
}

Write-Host "Spec:           $specFileName" -ForegroundColor White
Write-Host "Target Chapter: $TargetChapter" -ForegroundColor White
Write-Host "SemVer Bump:    $BumpType" -ForegroundColor White

# 3. Extract OpenSpec Requirements
$reqRegex = '(?ms)^### Requirement:\s*.*?(?=^### Requirement:|\n## [0-9]|\Z)'
$reqMatches = [System.Text.RegularExpressions.Regex]::Matches($specContent, $reqRegex)
$extractedRequirements = @()
foreach ($m in $reqMatches) {
    $trimmed = $m.Value.Trim()
    if ($trimmed.Length -gt 0) {
        $extractedRequirements += $trimmed
    }
}
Write-Host "Requirements found in delta spec: $($extractedRequirements.Count)" -ForegroundColor Cyan

if (-not (Test-Path $resolvedChapterPath)) {
    Write-Host "[FAIL] Target chapter does not exist at: $resolvedChapterPath" -ForegroundColor Red
    exit 1
}

if ($extractedRequirements.Count -eq 0) {
    Write-Host "[FAIL] No requirements ('### Requirement:') found in $specFileName. Aborting sync." -ForegroundColor Red
    exit 1
}

# 4. Archive Delta Spec to Vault
$vaultDir = Join-Path $repoRoot "memory\raw\vault"
if (-not (Test-Path $vaultDir)) { New-Item -ItemType Directory -Path $vaultDir -Force | Out-Null }

$vaultFileName = $specFileName
if ($vaultFileName.StartsWith("SPEC-")) {
    $vaultFileName = "RAW-" + $vaultFileName
}
$targetVaultPath = Join-Path $vaultDir $vaultFileName

Move-Item -Path $resolvedSpecPath -Destination $targetVaultPath -Force
Write-Host "[PASS] Delta spec archived to: $targetVaultPath" -ForegroundColor Green

$vaultLines = [System.IO.File]::ReadAllLines($targetVaultPath, $utf8NoBom)
$vaultLineCount = $vaultLines.Count

# 5. Synchronize into Main Wiki Chapter
$chapterContent = [System.IO.File]::ReadAllText($resolvedChapterPath, $utf8NoBom)
$newChapterVersion = "unversioned"

if ($chapterContent -match '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)') {
    $maj = [int]$matches[1]
    $min = [int]$matches[2]
    $pat = [int]$matches[3]
    if ($BumpType -eq "MAJOR") { $maj++; $min = 0; $pat = 0 }
    elseif ($BumpType -eq "MINOR") { $min++; $pat = 0 }
    else { $pat++ }
    $newChapterVersion = "$maj.$min.$pat"
    $chapterContent = [System.Text.RegularExpressions.Regex]::Replace($chapterContent, '(?m)^version:\s*.*$', "version: $newChapterVersion")
}

$syncSection = @"

## Synced Requirements from $vaultFileName
- **Archived Specification Pointer:** See ``memory/raw/vault/$vaultFileName`` lines 1-$vaultLineCount.

$($extractedRequirements -join "`n`n")
"@
$chapterContent += "`n$syncSection"
[System.IO.File]::WriteAllText($resolvedChapterPath, $chapterContent, $utf8NoBom)
Write-Host "[PASS] Main chapter $TargetChapter updated with requirements and bumped to v$newChapterVersion." -ForegroundColor Green

# 6. Run Memory Audit Verification via PSScriptRoot
$auditScript = Join-Path $PSScriptRoot "audit-memory.ps1"
if (Test-Path $auditScript) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $auditScript -RootDir $repoRoot
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] audit-memory.ps1 failed after spec sync." -ForegroundColor Red
        exit 1
    }
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  OpenSpec Sync & Archive Complete        " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
