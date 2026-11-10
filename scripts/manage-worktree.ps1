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
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  AntiGravity Worktree Manager (OMA-Style) " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$cwd = (Get-Location).ProviderPath
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$gitTop = (git -C $cwd rev-parse --show-toplevel 2>$null)
$ErrorActionPreference = $prevEap
$homeNorm = [System.IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
$cwdNorm = [System.IO.Path]::GetFullPath($cwd).TrimEnd('\', '/')
$isProjectGit = [bool]($gitTop -and ([System.IO.Path]::GetFullPath($gitTop).TrimEnd('\', '/') -ne $homeNorm -or $cwdNorm -eq $homeNorm))
if (-not $isProjectGit) {
    Write-Host "[FAIL] Not inside a project Git repository." -ForegroundColor Red
    exit 1
}
$repoRoot = $gitTop
$worktreeBaseDir = Join-Path $repoRoot ".worktrees"

if (-not $TargetBranch) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $branchOut = git -C $repoRoot branch --show-current 2>$null
    $ErrorActionPreference = $prevEap
    if ($branchOut) {
        $TargetBranch = ([string]$branchOut).Trim()
    }
    if (-not $TargetBranch) { $TargetBranch = "main" }
}

switch ($Action) {
    "list" {
        Write-Host "Active Git Worktrees:" -ForegroundColor White
        git -C $repoRoot worktree list
    }

    "create" {
        if (-not $BranchName) {
            Write-Host "[FAIL] -BranchName parameter is required for create action." -ForegroundColor Red
            exit 1
        }
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        git -C $repoRoot rev-parse --verify HEAD 2>$null | Out-Null
        $hasHead = ($LASTEXITCODE -eq 0)
        $ErrorActionPreference = $prevEap
        if (-not $hasHead) {
            Write-Host "[FAIL] Cannot create worktree: repository HEAD is unborn (create an initial commit first)." -ForegroundColor Red
            exit 1
        }

        $targetPath = Join-Path $worktreeBaseDir $BranchName
        if (-not (Test-Path $worktreeBaseDir)) { New-Item -ItemType Directory -Path $worktreeBaseDir -Force | Out-Null }

        Write-Host "Creating isolated worktree at $targetPath on branch $BranchName..." -ForegroundColor Cyan
        git -C $repoRoot worktree add $targetPath -b $BranchName
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
        git -C $repoRoot checkout $TargetBranch
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] Failed to checkout target branch $TargetBranch." -ForegroundColor Red
            exit 1
        }
        git -C $repoRoot merge $BranchName --no-ff -m "feat(worktree): merge isolated task $BranchName"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] Merge conflict encountered. Aborting merge." -ForegroundColor Red
            git -C $repoRoot merge --abort
            exit 1
        }

        Write-Host "Cleaning up worktree..." -ForegroundColor Cyan
        git -C $repoRoot worktree remove $targetPath --force
        git -C $repoRoot branch -d $BranchName
        Write-Host "[PASS] Worktree $BranchName cleanly merged and removed." -ForegroundColor Green
    }

    "cleanup" {
        if ($BranchName) {
            $targetPath = Join-Path $worktreeBaseDir $BranchName
            if (Test-Path $targetPath) {
                Write-Host "Removing worktree at $targetPath..." -ForegroundColor Cyan
                git -C $repoRoot worktree remove $targetPath --force
            }
            Write-Host "Deleting branch $BranchName..." -ForegroundColor Cyan
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            git -C $repoRoot branch -D $BranchName 2>$null | Out-Null
            $ErrorActionPreference = $prevEap
            Write-Host "[PASS] Worktree and branch $BranchName removed." -ForegroundColor Green
        }
        Write-Host "Pruning stale worktrees..." -ForegroundColor Cyan
        git -C $repoRoot worktree prune
        Write-Host "[PASS] Worktrees pruned." -ForegroundColor Green
    }
}
