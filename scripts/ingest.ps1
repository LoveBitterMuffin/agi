# ingest.ps1 - Automated Raw Inbox Ingestion for AntiGravity Docs-as-Code

param(
    [string]$RootDir = "."
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

function ConvertTo-AsciiSlug {
    param([string]$Text, [string]$Fallback = "item")
    $map = @{
        [char]0x0430 = "a";  [char]0x0431 = "b";  [char]0x0432 = "v";  [char]0x0433 = "g"
        [char]0x0434 = "d";  [char]0x0435 = "e";  [char]0x0451 = "yo"; [char]0x0436 = "zh"
        [char]0x0437 = "z";  [char]0x0438 = "i";  [char]0x0439 = "y";  [char]0x043A = "k"
        [char]0x043B = "l";  [char]0x043C = "m";  [char]0x043D = "n";  [char]0x043E = "o"
        [char]0x043F = "p";  [char]0x0440 = "r";  [char]0x0441 = "s";  [char]0x0442 = "t"
        [char]0x0443 = "u";  [char]0x0444 = "f";  [char]0x0445 = "kh"; [char]0x0446 = "ts"
        [char]0x0447 = "ch"; [char]0x0448 = "sh"; [char]0x0449 = "shch"; [char]0x044A = ""
        [char]0x044B = "y";  [char]0x044C = "";   [char]0x044D = "e";  [char]0x044E = "yu"
        [char]0x044F = "ya"
    }
    $sb = [System.Text.StringBuilder]::new()
    foreach ($ch in $Text.ToLowerInvariant().ToCharArray()) {
        if ($map.ContainsKey($ch)) { [void]$sb.Append($map[$ch]) }
        else { [void]$sb.Append($ch) }
    }
    $slug = ($sb.ToString() -replace '[^a-z0-9_\-]', '-' -replace '-{2,}', '-').Trim('-', '_')
    if (-not $slug) { return $Fallback }
    return $slug
}

$memoryDir = Join-Path $RootDir "memory"
$inboxDir = Join-Path $memoryDir "raw\inbox"
$vaultDir = Join-Path $memoryDir "raw\vault"
$currentYear = (Get-Date).ToString("yyyy")

if (-not (Test-Path $vaultDir)) { New-Item -ItemType Directory -Path $vaultDir -Force | Out-Null }

$inboxFiles = if (Test-Path $inboxDir) {
    @(Get-ChildItem -Path (Join-Path $inboxDir "*") -Exclude ".gitkeep" -File -ErrorAction SilentlyContinue)
} else { @() }

if ($inboxFiles.Count -eq 0) {
    Write-Host "Raw inbox is empty. Nothing to ingest." -ForegroundColor Yellow
    exit 0
}

# Determine next sequential vault ID
$existingVaultFiles = @(Get-ChildItem -Path $vaultDir -Filter "RAW-$currentYear-*.md" -File -ErrorAction SilentlyContinue)
$maxSeq = 0
foreach ($vf in $existingVaultFiles) {
    if ($vf.Name -match "RAW-$currentYear-([0-9]{3})_") {
        $num = [int]$matches[1]
        if ($num -gt $maxSeq) { $maxSeq = $num }
    }
}

foreach ($file in $inboxFiles) {
    $maxSeq++
    $seqStr = "{0:D3}" -f $maxSeq
    $cleanSlug = ConvertTo-AsciiSlug -Text $file.BaseName -Fallback "record"
    $vaultFileName = "RAW-$currentYear-$seqStr`_$cleanSlug.md"
    $vaultTarget = Join-Path $vaultDir $vaultFileName

    # Compute SHA256
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash

    # Move to Vault
    Move-Item -Path $file.FullName -Destination $vaultTarget -Force
    $lineCount = @(Get-Content $vaultTarget -Encoding UTF8).Count

    Write-Host "[INGESTED] $($file.Name) -> $vaultFileName ($lineCount lines, SHA256: $($hash.Substring(0,12))...)" -ForegroundColor Green
    Write-Host "           Pointers available: lines 1-$lineCount" -ForegroundColor DarkGray
}

Write-Host "Ingestion complete. Run .agents\scripts\audit-memory.ps1 to verify integrity." -ForegroundColor Cyan
