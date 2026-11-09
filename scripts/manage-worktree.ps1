# manage-worktree.ps1 - Isolated Git Worktree Lifecycle Manager (OMA / AntiGravity Pattern)
param(
    [ValidateSet("create", "verify-and-merge", "cleanup", "list")]
    [string]$Action = "list",

    [ValidatePattern('^[a-zA-Z0-9_\-\./]+$')]
    [ValidateScript({ -not $_.Contains("..") })]
    [string]$BranchName = "",

    [string]$TargetBranch = ""
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  AntiGravity Worktree Manager (OMA-Style) " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
$worktreeBaseDir = Join-Path $repoRoot ".worktrees"

if (-not $TargetBranch) {
    $TargetBranch = (git branch --show-current).Trim()
    if (-not $TargetBranch) { $TargetBranch = "main" }
}

switch ($Action) {
    "list" {
        Write-Host "Active Git Worktrees:" -ForegroundColor White
        git worktree list
    }

    "create" {
        if (-not $BranchName) {
            Write-Host "[FAIL] -BranchName parameter is required for create action." -ForegroundColor Red
            exit 1
        }
        $targetPath = Join-Path $worktreeBaseDir $BranchName
        if (-not (Test-Path $worktreeBaseDir)) { New-Item -ItemType Directory -Path $worktreeBaseDir -Force | Out-Null }

        Write-Host "Creating isolated worktree at $targetPath on branch $BranchName..." -ForegroundColor Cyan
        git worktree add $targetPath -b $BranchName
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] Failed to create git worktree." -ForegroundColor Red
            exit 1
        }
        Write-Host "[PASS] Isolated worktree ready at $targetPath" -ForegroundColor Green
        Write-Host "       Subagents can be dispatched with Workspace path pointing to this directory." -ForegroundColor DarkGray
    }

    "verify-and-merge" {
        if (-not $BranchName) {
            Write-Host "[FAIL] -BranchName parameter is required for verify-and-merge action." -ForegroundColor Red
            exit 1
        }
        $targetPath = Join-Path $worktreeBaseDir $BranchName
        if (-not (Test-Path $targetPath)) {
            Write-Host "[FAIL] Worktree path $targetPath does not exist." -ForegroundColor Red
            exit 1
        }

        Write-Host "Running Unified Harness inside isolated worktree $targetPath..." -ForegroundColor Cyan
        $harnessScript = Join-Path $targetPath ".agents\harness\run-harness.ps1"
        if (Test-Path $harnessScript) {
            Push-Location $targetPath
            try {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $harnessScript
                $harnessExit = $LASTEXITCODE
            } finally {
                Pop-Location
            }
            if ($harnessExit -ne 0) {
                Write-Host "[BLOCKED] Harness failed inside worktree $BranchName. Merge aborted!" -ForegroundColor Red
                exit 1
            }
        }

        Write-Host "[PASS] Harness passed. Merging $BranchName into $TargetBranch..." -ForegroundColor Green
        git checkout $TargetBranch
        git merge $BranchName --no-ff -m "feat(worktree): merge isolated task $BranchName"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] Merge conflict encountered. Aborting merge." -ForegroundColor Red
            git merge --abort
            exit 1
        }

        Write-Host "Cleaning up worktree..." -ForegroundColor Cyan
        git worktree remove $targetPath --force
        git branch -d $BranchName
        Write-Host "[PASS] Worktree $BranchName cleanly merged and removed." -ForegroundColor Green
    }

    "cleanup" {
        if ($BranchName) {
            $targetPath = Join-Path $worktreeBaseDir $BranchName
            if (Test-Path $targetPath) {
                Write-Host "Removing worktree at $targetPath..." -ForegroundColor Cyan
                git worktree remove $targetPath --force
            }
            Write-Host "Deleting branch $BranchName..." -ForegroundColor Cyan
            git branch -D $BranchName 2>$null
            Write-Host "[PASS] Worktree and branch $BranchName removed." -ForegroundColor Green
        }
        Write-Host "Pruning stale worktrees..." -ForegroundColor Cyan
        git worktree prune
        Write-Host "[PASS] Worktrees pruned." -ForegroundColor Green
    }
}
