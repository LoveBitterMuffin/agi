# load-subagents.ps1 - Dynamic Discovery and Registration Linter for Antigravity Subagents
param(
    [string]$WorkspaceRoot = ".",
    [string]$GlobalPluginsDir = "$HOME\.gemini\config\plugins"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Antigravity Subagent Discovery & Registry" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$discoveredSubagents = @()

# 1. Workspace Subagents (.agents/subagents/*.md)
$localSubagentDir = Join-Path $WorkspaceRoot ".agents\subagents"
if (Test-Path $localSubagentDir) {
    $localFiles = @(Get-ChildItem -Path (Join-Path $localSubagentDir "*") -Filter "*.md" -File)
    foreach ($file in $localFiles) {
        $content = Get-Content $file.FullName -Raw
        $name = $file.BaseName
        $desc = "No description"
        $tools = @()

        if ($content -match '(?ms)^---\s*\r?\n(.*?)\r?\n---') {
            $fm = $matches[1]
            if ($fm -match 'name:\s*([a-zA-Z0-9_\-]+)') { $name = $matches[1] }
            if ($fm -match 'description:\s*(.*?)(?=\r?\n[a-zA-Z0-9_\-]+:|\r?\n---|\Z)') { 
                $desc = ($matches[1] -replace '\s+', ' ').Trim() 
            }
            if ($fm -match '(?ms)tools:\s*\r?\n(.*?)(?=\r?\n[a-zA-Z0-9_\-]+:|\r?\n---|\Z)') {
                $tools = [regex]::Matches($matches[1], '-\s*([a-zA-Z0-9_\-]+)') | ForEach-Object { $_.Groups[1].Value }
            }
        }

        $discoveredSubagents += [PSCustomObject]@{
            Scope = "Workspace"
            Name = $name
            File = $file.Name
            ToolsCount = $tools.Count
            Tools = ($tools -join ", ")
            Description = if ($desc.Length -gt 60) { $desc.Substring(0, 57) + "..." } else { $desc }
        }
    }
}

# 2. Global Plugin Subagents (~/.gemini/config/plugins/*/subagents/*.md)
if (Test-Path $GlobalPluginsDir) {
    $globalFiles = @(Get-ChildItem -Path (Join-Path $GlobalPluginsDir "*\subagents\*.md") -File -ErrorAction SilentlyContinue)
    foreach ($file in $globalFiles) {
        $content = Get-Content $file.FullName -Raw
        $pluginName = $file.Directory.Parent.Name
        $name = $file.BaseName
        $desc = "No description"
        $tools = @()

        if ($content -match '(?ms)^---\s*\r?\n(.*?)\r?\n---') {
            $fm = $matches[1]
            if ($fm -match 'name:\s*([a-zA-Z0-9_\-]+)') { $name = $matches[1] }
            if ($fm -match 'description:\s*(.*?)(?=\r?\n[a-zA-Z0-9_\-]+:|\r?\n---|\Z)') { 
                $desc = ($matches[1] -replace '\s+', ' ').Trim() 
            }
            if ($fm -match '(?ms)tools:\s*\r?\n(.*?)(?=\r?\n[a-zA-Z0-9_\-]+:|\r?\n---|\Z)') {
                $tools = [regex]::Matches($matches[1], '-\s*([a-zA-Z0-9_\-]+)') | ForEach-Object { $_.Groups[1].Value }
            }
        }

        $discoveredSubagents += [PSCustomObject]@{
            Scope = "Global ($pluginName)"
            Name = $name
            File = $file.Name
            ToolsCount = $tools.Count
            Tools = ($tools -join ", ")
            Description = if ($desc.Length -gt 60) { $desc.Substring(0, 57) + "..." } else { $desc }
        }
    }
}

# 3. Built-in Subagents
$discoveredSubagents += [PSCustomObject]@{
    Scope = "Built-in"
    Name = "self"
    File = "(runtime)"
    ToolsCount = "All"
    Tools = "Full Parent Toolset"
    Description = "General-purpose worker with full tools & workspace capabilities"
}
$discoveredSubagents += [PSCustomObject]@{
    Scope = "Built-in"
    Name = "research"
    File = "(runtime)"
    ToolsCount = "Read-only"
    Tools = "read_file, search_web"
    Description = "Read-only codebase & documentation explorer"
}

$discoveredSubagents | Format-Table Scope, Name, Tools, Description -AutoSize

Write-Host "Total subagents discovered: $($discoveredSubagents.Count)" -ForegroundColor Green
Write-Host "To dispatch in conversation: invoke_subagent(TypeName: '<Name>', Role: '<Role>', Prompt: '<Prompt>')" -ForegroundColor Cyan
