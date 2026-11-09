# generate-repo-map.ps1 - Token-Dense Repository Symbol Map Generator (Aider-pattern)
param(
    [string]$SourceDir = "src",
    [string]$OutputFile = "memory\wiki\repo-map.md"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  AntiGravity Dynamic Repo-Map Generator   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
$targetDir = Join-Path $repoRoot $SourceDir
$outPath = Join-Path $repoRoot $OutputFile

$symbols = @()

if (-not (Test-Path $targetDir)) {
    Write-Host "[WARN] Source directory $SourceDir not found." -ForegroundColor Yellow
} else {
    # LRN-002: Always append '*' when using Get-ChildItem with -Include in PowerShell
    $srcFiles = @(Get-ChildItem -Path (Join-Path $targetDir "*") -Recurse -File -Include "*.ts", "*.js", "*.py", "*.go", "*.rs", "*.cs", "*.ps1")
    
    foreach ($file in $srcFiles) {
        $relPath = $file.FullName.Substring($repoRoot.Length + 1).Replace("\", "/")
        $fileUri = "file:///" + $file.FullName.Replace("\", "/")
        $lines = @(Get-Content $file.FullName)
        $fileSymbols = @()

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            $lineNum = $i + 1

            # Match TypeScript/JavaScript function/class/interface/type
            if ($line -match '^(export\s+)?(default\s+)?(async\s+)?function\s+([a-zA-Z0-9_]+)') {
                $fileSymbols += "fn $($matches[4]) (line $lineNum)"
            } elseif ($line -match '^(export\s+)?(class|interface|type|struct|enum)\s+([a-zA-Z0-9_]+)') {
                $fileSymbols += "$($matches[2]) $($matches[3]) (line $lineNum)"
            } elseif ($line -match '^(export\s+)?const\s+([a-zA-Z0-9_]+)\s*=\s*(async\s*)?\(') {
                $fileSymbols += "fn $($matches[2]) (line $lineNum)"
            }
            # Match Python
            elseif ($line -match '^(def|class)\s+([a-zA-Z0-9_]+)') {
                $fileSymbols += "$($matches[1]) $($matches[2]) (line $lineNum)"
            }
            # Match Go
            elseif ($line -match '^func\s+(\([^\)]+\)\s+)?([a-zA-Z0-9_]+)') {
                $fileSymbols += "func $($matches[2]) (line $lineNum)"
            }
            # Match Rust
            elseif ($line -match '^(pub\s+)?fn\s+([a-zA-Z0-9_]+)') {
                $fileSymbols += "fn $($matches[2]) (line $lineNum)"
            }
            # Match C#
            elseif ($line -match '^(public|internal|protected|private)?\s*(static\s+)?(class|interface|struct|record)\s+([a-zA-Z0-9_]+)') {
                $fileSymbols += "$($matches[3]) $($matches[4]) (line $lineNum)"
            }
            # Match PowerShell (supporting hyphens in cmdlet/function names)
            elseif ($line -match '^function\s+([a-zA-Z0-9_\-]+)') {
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
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::UTF8)

$lineCount = $sb.ToString().Split("`n").Count
Write-Host "[PASS] Repo-Map generated at $OutputFile ($lineCount lines)." -ForegroundColor Green
