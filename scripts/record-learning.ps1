# record-learning.ps1 - Automated Learning Reflector (Harness2 / Antigravity Pattern)
param(
    [Parameter(Mandatory=$true)]
    [string]$Title,

    [Parameter(Mandatory=$true)]
    [Alias("Context")]
    [string]$Trigger,

    [Parameter(Mandatory=$true)]
    [Alias("Rule")]
    [string]$AntiPattern,

    [Parameter(Mandatory=$true)]
    [Alias("Correction", "DeterministicInvariant")]
    [string]$CorrectivePattern,

    [string]$RootCause = "",
    [string]$VerificationEvidence = "",
    [string]$RootDir = ""
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

if ($RootDir) {
    $repoRoot = [System.IO.Path]::GetFullPath($RootDir)
} else {
    $cwd = (Get-Location).ProviderPath
    $gitTop = (git -C $cwd rev-parse --show-toplevel 2>$null)
    $homeNorm = [System.IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
    $cwdNorm = [System.IO.Path]::GetFullPath($cwd).TrimEnd('\', '/')
    $repoRoot = if ($gitTop -and ([System.IO.Path]::GetFullPath($gitTop).TrimEnd('\', '/') -ne $homeNorm -or $cwdNorm -eq $homeNorm)) { $gitTop } else { $cwd }
}
$learningsFile = Join-Path $repoRoot "memory\wiki\chapters\099_learnings.md"

if (-not (Test-Path $learningsFile)) {
    Write-Host "[FAIL] Learnings file $learningsFile not found." -ForegroundColor Red
    exit 1
}

$content = [System.IO.File]::ReadAllText($learningsFile, $utf8NoBom)

# 1. Determine Next LRN-YYYY-NNN ID without partial prefix collisions (e.g. LRN-2026-004)
$lrnMatches = [System.Text.RegularExpressions.Regex]::Matches($content, '(?<![0-9A-Za-z])LRN-(?:\d{4}-)?(\d{3})(?![0-9])')
$maxId = 0
foreach ($m in $lrnMatches) {
    $val = [int]$m.Groups[1].Value
    if ($val -gt $maxId) { $maxId = $val }
}
$currentYear = (Get-Date).ToString("yyyy")
$today = (Get-Date).ToString("yyyy-MM-dd")
$nextId = "{0:D3}" -f ($maxId + 1)
$lrnTag = "LRN-$currentYear-$nextId"

$dateTrigger = if ($Trigger -match '^\d{4}-\d{2}-\d{2}') { $Trigger } else { "$today / $Trigger" }
$rootCauseText = if ($RootCause) { $RootCause } else { "Observed during trigger: $Trigger" }
$evidenceText = if ($VerificationEvidence) { $VerificationEvidence } else { "Pending shielded harness verification" }

# 2. Format New Learning Block (all 5 harness2-learning fields)
$newBlock = @"
### [$lrnTag] $Title
- **Date / Trigger:** $dateTrigger
- **Root Cause:** $rootCauseText
- **Anti-Pattern:** $AntiPattern
- **Deterministic Invariant:** $CorrectivePattern
- **Verification Evidence:** $evidenceText

"@

# 3. Bump PATCH SemVer in Frontmatter (safe fallback if missing)
$newVersion = "unversioned"
if ($content -match '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)') {
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3] + 1
    $newVersion = "$major.$minor.$patch"
    $content = [System.Text.RegularExpressions.Regex]::Replace($content, '(?m)^version:\s*.*$', "version: $newVersion")
}

# 4. Insert before Section 4
$targetHeading = "## 4. Template for Logging New Learnings"
if ($content.Contains($targetHeading)) {
    $content = $content.Replace($targetHeading, "$newBlock`n$targetHeading")
} else {
    $content += "`n$newBlock"
}

[System.IO.File]::WriteAllText($learningsFile, $content, $utf8NoBom)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Harness Learning Reflected into Memory   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "[PASS] Recorded [$lrnTag]: $Title" -ForegroundColor Green
Write-Host "       Updated 099_learnings.md to version $newVersion" -ForegroundColor Yellow
