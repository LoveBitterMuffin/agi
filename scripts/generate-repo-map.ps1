# generate-repo-map.ps1 - Token-Dense Repository Symbol Map Generator (Aider-pattern)
param(
    [string]$SourceDir = "src",
    [string]$OutputFile = "memory\wiki\repo-map.md",
    [string]$RootDir = ""
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  AntiGravity Dynamic Repo-Map Generator   " -ForegroundColor Cyan
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
$repoRootClean = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\', '/')
$outPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) { $OutputFile } else { Join-Path $repoRoot $OutputFile }

# Auto-detect source roots if SourceDir was not explicitly passed
$targetDirs = @()
if ($PSBoundParameters.ContainsKey("SourceDir")) {
    $explicitDir = if ([System.IO.Path]::IsPathRooted($SourceDir)) { $SourceDir } else { Join-Path $repoRoot $SourceDir }
    if (Test-Path $explicitDir) { $targetDirs += $explicitDir }
} else {
    foreach ($candidate in @("src", "handwriting_system/src", "app", "lib")) {
        $candPath = Join-Path $repoRoot $candidate
        if (Test-Path $candPath) { $targetDirs += $candPath }
    }
}

$symbols = @()
$allowedExts = @(".ts", ".js", ".py", ".go", ".rs", ".cs", ".ps1")

if ($targetDirs.Count -eq 0) {
    Write-Host "[WARN] Source directory '$SourceDir' (and fallback roots) not found." -ForegroundColor Yellow
} else {
    $srcFiles = @()
    foreach ($td in $targetDirs) {
        $srcFiles += @(Get-ChildItem -Path $td -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Extension -in $allowedExts -and $_.FullName -notmatch '[\\/](?:__pycache__|node_modules|\.git|dist|\.venv)[\\/]'
        })
    }
    $srcFiles = @($srcFiles | Sort-Object FullName -Unique)

    foreach ($file in $srcFiles) {
        $relPath = if ($file.FullName.Length -gt ($repoRootClean.Length + 1) -and $file.FullName.StartsWith($repoRootClean, [System.StringComparison]::OrdinalIgnoreCase)) {
            $file.FullName.Substring($repoRootClean.Length + 1).Replace("\", "/")
        } else {
            $file.Name
        }
        $fileUri = "file:///" + $file.FullName.Replace("\", "/")
        $lines = @(Get-Content $file.FullName -Encoding UTF8)
        $fileSymbols = @()

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            $lineNum = $i + 1

            if ($line -match '^(export\s+)?(default\s+)?(async\s+)?function\s+([a-zA-Z0-9_]+)') {
                $fileSymbols += "fn $($matches[4]) (line $lineNum)"
            } elseif ($line -match '^(export\s+)?(class|interface|type|struct|enum)\s+([a-zA-Z0-9_]+)') {
                $fileSymbols += "$($matches[2]) $($matches[3]) (line $lineNum)"
            } elseif ($line -match '^(export\s+)?const\s+([a-zA-Z0-9_]+)\s*=\s*(async\s*)?\(') {
                $fileSymbols += "fn $($matches[2]) (line $lineNum)"
            } elseif ($line -match '^(async\s+def|def|class)\s+([a-zA-Z0-9_]+)') {
                $fileSymbols += "$($matches[1]) $($matches[2]) (line $lineNum)"
            } elseif ($line -match '^func\s+(\([^\)]+\)\s+)?([a-zA-Z0-9_]+)') {
                $fileSymbols += "func $($matches[2]) (line $lineNum)"
            } elseif ($line -match '^(pub\s+)?fn\s+([a-zA-Z0-9_]+)') {
                $fileSymbols += "fn $($matches[2]) (line $lineNum)"
            } elseif ($line -match '^(public|internal|protected|private)?\s*(static\s+)?(class|interface|struct|record)\s+([a-zA-Z0-9_]+)') {
                $fileSymbols += "$($matches[3]) $($matches[4]) (line $lineNum)"
            } elseif ($line -match '^function\s+([a-zA-Z0-9_\-]+)') {
                $fileSymbols += "fn $($matches[1]) (line $lineNum)"
            }
        }

        if ($fileSymbols.Count -gt 0) {
            $symbols += [PSCustomObject]@{
                File = $relPath
                Uri = $fileUri
                Symbols = $fileSymbols
            }
        }
    }
}

# Generate Markdown Repo-Map
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# Repository Symbol Map (Auto-Generated)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("> Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'). Read this file to understand codebase topology without reading full source files.")
[void]$sb.AppendLine("")

if ($symbols.Count -eq 0) {
    [void]$sb.AppendLine("## Source Modules")
    [void]$sb.AppendLine("*No application symbols declared yet in $SourceDir/.*")
} else {
    foreach ($entry in $symbols) {
        [void]$sb.AppendLine("### [$($entry.File)]($($entry.Uri))")
        foreach ($sym in $entry.Symbols) {
            $codeSym = [char]96 + $sym + [char]96
            [void]$sb.AppendLine("- $codeSym")
        }
        [void]$sb.AppendLine("")
    }
}

$outDir = Split-Path -Parent $outPath
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), $utf8NoBom)

$lineCount = $sb.ToString().Split("`n").Count
Write-Host "[PASS] Repo-Map generated at $OutputFile ($lineCount lines)." -ForegroundColor Green
