# ingest.ps1 - Automated Raw Inbox Ingestion for AntiGravity Docs-as-Code

param(
    [string]$RootDir = "."
)

$ErrorActionPreference = "Stop"

$memoryDir = Join-Path $RootDir "memory"
$inboxDir = Join-Path $memoryDir "raw\inbox"
$vaultDir = Join-Path $memoryDir "raw\vault"
$currentYear = (Get-Date).ToString("yyyy")

$inboxFiles = @(Get-ChildItem -Path (Join-Path $inboxDir "*") -Exclude ".gitkeep" -File -ErrorAction SilentlyContinue)

if ($inboxFiles.Count -eq 0) {
    Write-Host "Raw inbox is empty. Nothing to ingest." -ForegroundColor Yellow
    exit 0
}

# Determine next sequential vault ID
$existingVaultFiles = Get-ChildItem -Path $vaultDir -Filter "RAW-$currentYear-*.md" -ErrorAction SilentlyContinue
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
    $cleanSlug = ($file.BaseName -replace '[^a-zA-Z0-9_\-]', '-').ToLower()
    $vaultFileName = "RAW-$currentYear-$seqStr`_$cleanSlug.md"
    $vaultTarget = Join-Path $vaultDir $vaultFileName

    # Compute SHA256
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash

    # Move to Vault
    Move-Item -Path $file.FullName -Destination $vaultTarget -Force
    $lineCount = (Get-Content $vaultTarget).Count

    Write-Host "[INGESTED] $($file.Name) -> $vaultFileName ($lineCount lines, SHA256: $($hash.Substring(0,12))...)" -ForegroundColor Green
    Write-Host "           Pointers available: lines 1-$lineCount" -ForegroundColor DarkGray
}

Write-Host "Ingestion complete. Run .agents\scripts\audit-memory.ps1 to verify integrity." -ForegroundColor Cyan
