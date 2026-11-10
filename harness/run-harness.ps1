# run-harness.ps1 - Universal 4-Stage Embedded CI/CD Verification Harness
param(
    [string]$RootDir = ".",
    [switch]$Fast,
    [switch]$SelfHeal
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

$resolvedRoot = (Resolve-Path $RootDir).Path
$scriptsDir = Join-Path $resolvedRoot ".agents\scripts"
$pluginScriptsDir = Join-Path $PSScriptRoot "..\scripts"
$failedStages = @()

function Invoke-StageScript {
    param([string]$Label, [string]$ScriptName, [string[]]$Arguments = @())
    $scriptPath = Join-Path $scriptsDir $ScriptName
    if (-not (Test-Path $scriptPath)) {
        $scriptPath = Join-Path $pluginScriptsDir $ScriptName
    }
    if (-not (Test-Path $scriptPath)) {
        Write-Host "[FAIL] Missing script: $ScriptName (checked $scriptsDir and $pluginScriptsDir)" -ForegroundColor Red
        return $false
    }
    Write-Host "`n--- $Label ($ScriptName) ---" -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments | Out-Host
    return ($LASTEXITCODE -eq 0)
}

function Detect-SourceDir {
    param([string]$Root)
    foreach ($rel in @("src", "app", "lib", "packages", "internal", "hooks")) {
        $cand = Join-Path $Root $rel
        if (Test-Path $cand) { return $rel }
    }
    return ""
}

function Detect-TestCommand {
    param([string]$Root, [switch]$IsFast)
    $pyTests = Join-Path $Root "tests"
    if ((Test-Path (Join-Path $Root "pytest.ini")) -or (Test-Path (Join-Path $Root "pyproject.toml"))) {
        if ($IsFast -and (Test-Path (Join-Path $pyTests "test_fast.py"))) {
            return @{ Cmd = "python -m pytest tests/test_fast.py"; Log = "pytest_fast" }
        }
        return @{ Cmd = "python -m pytest"; Log = "pytest_full" }
    }
    if ((Test-Path $pyTests) -and (Get-ChildItem -Path $pyTests -Filter "*.py" -ErrorAction SilentlyContinue | Select-Object -First 1)) {
        return @{ Cmd = "python -m pytest tests"; Log = "pytest_tests" }
    }
    $pkgJson = Join-Path $Root "package.json"
    if (Test-Path $pkgJson) {
        $pkgRaw = Get-Content $pkgJson -Raw -Encoding UTF8
        if ($pkgRaw -match '"test"\s*:\s*"([^"]+)"' -and $matches[1] -notmatch 'no test specified') {
            return @{ Cmd = "npm test"; Log = "npm_test" }
        }
    }
    $mjsTests = Get-ChildItem -Path $Root -Recurse -Filter "*.test.mjs" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\node_modules\\' }
    if ($mjsTests) {
        return @{ Cmd = "node --test tests/*.test.mjs"; Log = "node_test" }
    }
    if (Test-Path (Join-Path $Root "Cargo.toml")) {
        return @{ Cmd = "cargo test"; Log = "cargo_test" }
    }
    if (Test-Path (Join-Path $Root "go.mod")) {
        return @{ Cmd = "go test ./..."; Log = "go_test" }
    }
    return $null
}

Push-Location $resolvedRoot
try {
    $srcDir = Detect-SourceDir -Root $resolvedRoot
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  AntiGravity 4-Stage Verification Harness" -ForegroundColor Cyan
    Write-Host "  Mode: $(if ($Fast) { 'FAST' } else { 'FULL' }) | SelfHeal: $SelfHeal | Src: $(if ($srcDir) { $srcDir } else { 'auto' })" -ForegroundColor DarkCyan
    Write-Host "==========================================" -ForegroundColor Cyan

    $s1 = Invoke-StageScript -Label "Stage 1: Memory Integrity" -ScriptName "audit-memory.ps1" -Arguments @("-RootDir", $resolvedRoot)
    if (-not $s1 -and $SelfHeal) {
        Write-Host "[SELF-HEAL] Running self-heal.ps1 -All and retrying Stage 1..." -ForegroundColor Yellow
        $null = Invoke-StageScript -Label "Stage 1 Self-Heal" -ScriptName "self-heal.ps1" -Arguments @("-All")
        $s1 = Invoke-StageScript -Label "Stage 1 Retry" -ScriptName "audit-memory.ps1" -Arguments @("-RootDir", $resolvedRoot)
    }
    if (-not $s1) { $failedStages += "Stage 1 (audit-memory)" }

    $s2a = Invoke-StageScript -Label "Stage 2a: Code Audit" -ScriptName "audit-code.ps1"
    $s2b = Invoke-StageScript -Label "Stage 2b: Restraint Audit" -ScriptName "audit-restraint.ps1"
    if (-not ($s2a -and $s2b)) { $failedStages += "Stage 2 (code/restraint audit)" }

    $testInfo = Detect-TestCommand -Root $resolvedRoot -IsFast:$Fast
    $s3 = $true
    if ($testInfo) {
        $s3 = Invoke-StageScript -Label "Stage 3: Test Matrix" -ScriptName "run-shielded.ps1" -Arguments @(
            "-CommandLine", $testInfo.Cmd,
            "-LogName", $testInfo.Log
        )
        if (-not $s3) { $failedStages += "Stage 3 ($($testInfo.Log))" }
    } else {
        Write-Host "`n--- Stage 3: Test Matrix ---" -ForegroundColor Cyan
        Write-Host "[SKIP] No pytest, npm test, or node --test suite detected." -ForegroundColor Yellow
    }

    $s4a = Invoke-StageScript -Label "Stage 4a: Release Audit" -ScriptName "release-audit.ps1" -Arguments @("-RootDir", $resolvedRoot)
    $s4b = Invoke-StageScript -Label "Stage 4b: Ping-Pong VerifyOnly" -ScriptName "run-pingpong.ps1" -Arguments @("-VerifyOnly")
    if (-not ($s4a -and $s4b)) { $failedStages += "Stage 4 (release/pingpong)" }

    Write-Host "`n==========================================" -ForegroundColor Cyan
    if ($failedStages.Count -eq 0) {
        Write-Host "[PASS] All 4 harness stages passed." -ForegroundColor Green
        exit 0
    }
    Write-Host "[FAIL] Harness failed in: $($failedStages -join ', ')" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
