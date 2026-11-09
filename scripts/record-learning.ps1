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
    [Alias("Correction")]
    [string]$CorrectivePattern
)

$ErrorActionPreference = "Stop"

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
$learningsFile = Join-Path $repoRoot "memory\wiki\chapters\099_learnings.md"

if (-not (Test-Path $learningsFile)) {
    Write-Host "[FAIL] Learnings file $learningsFile not found." -ForegroundColor Red
    exit 1
}

$content = [System.IO.File]::ReadAllText($learningsFile, [System.Text.Encoding]::UTF8)

# 1. Determine Next LRN-xxx ID
$matches = [System.Text.RegularExpressions.Regex]::Matches($content, 'LRN-(\d{3})')
$maxId = 0
foreach ($m in $matches) {
    $val = [int]$m.Groups[1].Value
    if ($val -gt $maxId) { $maxId = $val }
}
$nextId = "{0:D3}" -f ($maxId + 1)
$lrnTag = "LRN-$nextId"

# 2. Format New Learning Block
$newBlock = @"
### $($lrnTag): $Title
- **Trigger / Context:** $Trigger
- **Anti-Pattern:** $AntiPattern
- **Corrective Pattern:** $CorrectivePattern

"@

# 3. Bump PATCH SemVer in Frontmatter
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

[System.IO.File]::WriteAllText($learningsFile, $content, [System.Text.Encoding]::UTF8)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Harness Learning Reflected into Memory   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "[PASS] Recorded $($lrnTag): $Title" -ForegroundColor Green
Write-Host "       Updated 099_learnings.md to version $newVersion" -ForegroundColor Yellow
