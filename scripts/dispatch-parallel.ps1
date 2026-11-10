# dispatch-parallel.ps1 - Parallel Swarm Fan-Out Partitioning & Boundary Validator
param(
    [string]$TaskTitle = "Parallel Task Slice",
    [ValidateSet("self", "research", "explorer-agent", "backend-specialist", "frontend-specialist", "test-engineer", "security-auditor", "devops-engineer")]
    [string]$TypeName = "self",
    [string[]]$Domains = @(),
    [string]$WorkspaceMode = "inherit",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Parallel Swarm Fan-Out Dispatcher       " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$cwd = (Get-Location).ProviderPath
$gitTop = (git -C $cwd rev-parse --show-toplevel 2>$null)
$homeNorm = [System.IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
$cwdNorm = [System.IO.Path]::GetFullPath($cwd).TrimEnd('\', '/')
$repoRoot = if ($gitTop -and ([System.IO.Path]::GetFullPath($gitTop).TrimEnd('\', '/') -ne $homeNorm -or $cwdNorm -eq $homeNorm)) { $gitTop } else { $cwd }

# Map specialist alias to valid native TypeName (self / research)
$nativeTypeName = if ($TypeName -in @("research", "explorer-agent", "security-auditor")) { "research" } else { "self" }
$specialistLabel = if ($TypeName -in @("self", "research")) { "Specialist" } else { $TypeName }

# Auto-detect domain shards if -Domains was not explicitly supplied
if ($Domains.Count -eq 0) {
    foreach ($rootCand in @("src", "handwriting_system/src", "app", "lib")) {
        $candPath = Join-Path $repoRoot $rootCand
        if (Test-Path $candPath) {
            $subDirs = @(Get-ChildItem -Path $candPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @("__pycache__", "node_modules", "dist") } | Select-Object -First 4)
            if ($subDirs.Count -ge 2) {
                $Domains = @($subDirs | ForEach-Object { "$rootCand/$($_.Name)" })
                break
            } else {
                $Domains += $rootCand
            }
        }
    }
    if ($Domains.Count -eq 0) {
        $Domains = @("src/landing", "src/platform", "src/qa")
    }
}

# Normalize Domain List (supports arrays and comma-separated strings)
$domainList = @()
foreach ($d in $Domains) {
    if ($d -match ',') {
        $domainList += ($d -split ',' | ForEach-Object { $_.Trim(" '`"()@") })
    } else {
        $domainList += $d.Trim(" '`"()@")
    }
}
$Domains = @($domainList | Where-Object { $_ -and $_.Length -gt 0 })

# 1. Validate Disjoint Domain Boundaries
Write-Host "Validating domain partitioning for $($Domains.Count) parallel workers..." -ForegroundColor White
$sortedDomains = $Domains | Sort-Object Length

for ($i = 0; $i -lt $sortedDomains.Count; $i++) {
    for ($j = $i + 1; $j -lt $sortedDomains.Count; $j++) {
        $d1 = $sortedDomains[$i].TrimEnd('/', '\') + '/'
        $d2 = $sortedDomains[$j].TrimEnd('/', '\') + '/'
        if ($d2.StartsWith($d1, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Host "[FAIL] Overlapping domain boundary detected: '$($sortedDomains[$i])' overlaps with '$($sortedDomains[$j])'!" -ForegroundColor Red
            exit 1
        }
    }
}
Write-Host "[PASS] Zero overlapping paths. Domains are strictly disjoint." -ForegroundColor Green

# 2. Generate Structured Prompts for Each Worker
$shieldedPath = Join-Path $PSScriptRoot "run-shielded.ps1"
$dispatches = @()
for ($i = 0; $i -lt $Domains.Count; $i++) {
    $dom = $Domains[$i]
    $roleName = "Worker-$($i+1): $dom $specialistLabel"

    $prompt = @"
### 1. Role & Objective
You are $roleName (TypeName: $nativeTypeName) executing an isolated sub-task for: '$TaskTitle'.
Your objective is to inspect, analyze, or modify logic strictly within your assigned domain: '$dom'.

### 2. Resource Boundaries
- Allowed Domain: $dom/**
- Prohibited Paths: All other modules/subsystems outside $dom.
- Line Read Ban: Strictly use range reads (read_file with StartLine/EndLine). Never read files >250 lines in full.

### 3. Action Checklist
1. Inspect symbols and file topology in $dom.
2. Adhere to Rule 04: New files <=150 lines, functions <=30 lines, zero slop comments, no empty catch/except.
3. Execute console commands through $shieldedPath to prevent context bloat.
4. Verify changes locally within your domain.

### 4. Expected Deliverable
Return a concise summary (max 15 lines):
- Domain: $dom
- Status: [SUCCESS / BLOCKED]
- Files Touched: [List]
- Verification Proof: [Exit code & duration]
"@

    $dispatches += @{
        TypeName = $nativeTypeName
        AgentProfile = $TypeName
        Role = $roleName
        Workspace = $WorkspaceMode
        Model = "inherit"
        Prompt = $prompt
        Domain = $dom
    }
}

# 3. Output Dispatch Matrix
Write-Host "`nGenerated $($dispatches.Count) Parallel Worker Dispatches:" -ForegroundColor Cyan
foreach ($d in $dispatches) {
    Write-Host "  - [$($d.TypeName)] $($d.Role) -> Target: $($d.Domain) (Mode: $($d.Workspace))" -ForegroundColor Yellow
}

if ($DryRun) {
    Write-Host "`n[DRY-RUN] Dispatches validated. Ready for single-turn batch invoke_subagent." -ForegroundColor Green
    exit 0
}

# Write dispatch specification to scratch using BOM-free UTF-8
$scratchDir = Join-Path $repoRoot "scratch"
if (-not (Test-Path $scratchDir)) { New-Item -ItemType Directory -Path $scratchDir | Out-Null }
$outJson = Join-Path $scratchDir "parallel_dispatch_plan.json"
[System.IO.File]::WriteAllText($outJson, ($dispatches | ConvertTo-Json -Depth 5), $utf8NoBom)
Write-Host "`n[SUCCESS] Parallel dispatch plan written to: scratch/parallel_dispatch_plan.json" -ForegroundColor Green
exit 0
