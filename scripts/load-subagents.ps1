# load-subagents.ps1 - Dynamic Discovery and Registration Linter for Antigravity Subagents
param(
    [string]$WorkspaceRoot = ".",
    [string]$GlobalPluginsDir = "$HOME\.gemini\config\plugins"
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

function Parse-AgentCard {
    param([System.IO.FileInfo]$File, [string]$ScopeLabel)
    $content = Get-Content $File.FullName -Raw -Encoding UTF8
    $name = $File.BaseName
    $desc = "No description"
    $tools = @()

    if ($content -match '(?ms)^---\s*\r?\n(.*?)\r?\n---') {
        $fm = $matches[1]
        if ($fm -match 'name:\s*([a-zA-Z0-9_\-]+)') { $name = $matches[1] }
        if ($fm -match 'description:\s*(.*?)(?=\r?\n[a-zA-Z0-9_\-]+:|\r?\n---|\Z)') {
            $desc = ($matches[1] -replace '\s+', ' ').Trim()
        }
        if ($fm -match '(?ms)tools:\s*\r?\n(.*?)(?=\r?\n[a-zA-Z0-9_\-]+:|\r?\n---|\Z)') {
            $tools = @([regex]::Matches($matches[1], '-\s*([a-zA-Z0-9_\-]+)') | ForEach-Object { $_.Groups[1].Value })
        }
    }

    return [PSCustomObject]@{
        Scope = $ScopeLabel
        Name = $name
        File = $File.Name
        ToolsCount = $tools.Count
        Tools = ($tools -join ", ")
        Description = if ($desc.Length -gt 60) { $desc.Substring(0, 57) + "..." } else { $desc }
    }
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Antigravity Subagent Discovery & Registry" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$discoveredSubagents = @()

# 1. Workspace Subagents (.agents/agents/*.md with fallback .agents/subagents/*.md)
$localAgentsDir = Join-Path $WorkspaceRoot ".agents\agents"
$localSubDir = Join-Path $WorkspaceRoot ".agents\subagents"
$localTargetDir = if (Test-Path $localAgentsDir) { $localAgentsDir } elseif (Test-Path $localSubDir) { $localSubDir } else { "" }

if ($localTargetDir) {
    $localFiles = @(Get-ChildItem -Path (Join-Path $localTargetDir "*") -Filter "*.md" -File -ErrorAction SilentlyContinue)
    foreach ($file in $localFiles) {
        $discoveredSubagents += Parse-AgentCard -File $file -ScopeLabel "Workspace"
    }
}

# 2. Plugin Local Agents (relative to PSScriptRoot) or Global Plugins (~/.gemini/config/plugins/*/agents/*.md -> fallback subagents/*.md)
$pluginDirs = @()
if (Test-Path $GlobalPluginsDir) {
    $pluginDirs += @(Get-ChildItem -Path $GlobalPluginsDir -Directory -ErrorAction SilentlyContinue)
}
$parentPlugin = Split-Path -Parent $PSScriptRoot
if ($parentPlugin -and (Test-Path $parentPlugin)) {
    $pluginDirs = @([System.IO.DirectoryInfo]::new($parentPlugin)) + $pluginDirs
}

$seenPluginScopes = [System.Collections.Generic.HashSet[string]]::new()
foreach ($pDir in $pluginDirs) {
    if (-not $seenPluginScopes.Add($pDir.FullName.ToLowerInvariant())) { continue }
    $pAgents = Join-Path $pDir.FullName "agents"
    $pSubs = Join-Path $pDir.FullName "subagents"
    $targetSubDir = if (Test-Path $pAgents) { $pAgents } elseif (Test-Path $pSubs) { $pSubs } else { "" }
    if ($targetSubDir) {
        $globalFiles = @(Get-ChildItem -Path (Join-Path $targetSubDir "*") -Filter "*.md" -File -ErrorAction SilentlyContinue)
        foreach ($file in $globalFiles) {
            $discoveredSubagents += Parse-AgentCard -File $file -ScopeLabel "Plugin ($($pDir.Name))"
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
Write-Host "To dispatch in conversation: invoke_subagent(TypeName: 'self'|'research', Role: '<Name>', Prompt: '<Prompt>')" -ForegroundColor Cyan
