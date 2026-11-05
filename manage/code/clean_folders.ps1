<#
.SYNOPSIS
    Deletes files and folders based on structured list with size reporting.
.DESCRIPTION
    Reads paths from path_for_clean.txt with action types:
    - [DELETE] - delete file or folder completely
    - [CLEAR]  - delete folder contents only (keep folder)
    - [FILE]   - delete file
    Reports size of deleted items.
.PARAMETER FilePath
    Path to the text file with list of paths. Default: .\path_for_clean.txt
.PARAMETER WhatIf
    Preview mode. Shows what would be deleted (with sizes) without actual deletion.
#>

param (
    [string]$FilePath = ".\path_for_clean.txt",
    [switch]$WhatIf
)

# Helper: format bytes to human-readable size
function Format-ByteSize([long]$bytes) {
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return "{0:N2} KB" -f ($bytes / 1KB) }
    return "$bytes B"
}

# Helper: calculate size of a file or folder (recursively)
function Get-ItemSize([string]$path, [switch]$Recurse) {
    try {
        $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if (-not $item.PSIsContainer) {
            return $item.Length
        }
        if ($Recurse) {
            $sum = (Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
            return [long]($sum)
        } else {
            $sum = (Get-ChildItem -LiteralPath $path -Force -File -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
            return [long]($sum)
        }
    }
    catch {
        return 0
    }
}

# Check if the file exists
if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

Write-Host "Reading paths from: $FilePath" -ForegroundColor Cyan

$lines = Get-Content -LiteralPath $FilePath | Where-Object { 
    $_.Trim() -ne "" -and $_.Trim() -notmatch "^#" 
}

if ($lines.Count -eq 0) {
    Write-Warning "File $FilePath is empty or contains no valid paths."
    exit 0
}

Write-Host "Found $($lines.Count) entries to process." -ForegroundColor Cyan
Write-Host "---------------------------------------------------"

$successCount = 0
$errorCount   = 0
$totalBytes   = [long]0
$details      = @()

foreach ($line in $lines) {
    $line = $line.Trim()
    
    $action = ""
    $targetPath = ""
    
    if ($line -match "^\[(DELETE|CLEAR|FILE)\]\s*(.+)$") {
        $action = $matches[1]
        $targetPath = $matches[2].Trim()
    }
    else {
        $action = "DELETE"
        $targetPath = $line
        Write-Warning "No action prefix found, using DELETE: $targetPath"
    }

    if (-not (Test-Path -LiteralPath $targetPath)) {
        Write-Warning "[SKIP] Path not found: $targetPath"
        $errorCount++
        continue
    }

    $item = Get-Item -LiteralPath $targetPath -Force

    switch ($action) {
        "FILE" {
            if ($item.PSIsContainer) {
                Write-Warning "[ERROR] $targetPath is a folder, not a file. Use [DELETE] or [CLEAR]"
                $errorCount++
                continue
            }
            
            $size = $item.Length
            $sizeStr = Format-ByteSize $size
            
            if ($WhatIf) {
                Write-Host "[WHAT IF] [FILE] $targetPath  ($sizeStr)" -ForegroundColor DarkYellow
                $successCount++
                $totalBytes += $size
                $details += [pscustomobject]@{
                    Action = 'FILE'
                    Path   = $targetPath
                    Size   = $size
                    Status = 'WHAT IF'
                }
            } else {
                Write-Host "[FILE] Deleting: $targetPath  ($sizeStr)" -ForegroundColor Yellow
                try {
                    Remove-Item -LiteralPath $targetPath -Force -ErrorAction Stop
                    Write-Host "[DELETED] $targetPath" -ForegroundColor Green
                    $totalBytes += $size
                    $successCount++
                    $details += [pscustomobject]@{
                        Action = 'FILE'
                        Path   = $targetPath
                        Size   = $size
                        Status = 'OK'
                    }
                }
                catch {
                    Write-Error "Error deleting file '$targetPath': $_"
                    $errorCount++
                    $details += [pscustomobject]@{
                        Action = 'FILE'
                        Path   = $targetPath
                        Size   = 0
                        Status = "ERROR: $($_.Exception.Message)"
                    }
                }
            }
        }
        
        "CLEAR" {
            if (-not $item.PSIsContainer) {
                Write-Warning "[ERROR] $targetPath is a file, not a folder. Use [FILE] or [DELETE]"
                $errorCount++
                continue
            }
            
            $size = Get-ItemSize $targetPath -Recurse
            $sizeStr = Format-ByteSize $size
            
            if ($WhatIf) {
                Write-Host "[WHAT IF] [CLEAR] $targetPath  ($sizeStr)" -ForegroundColor DarkYellow
                $successCount++
                $totalBytes += $size
                $details += [pscustomobject]@{
                    Action = 'CLEAR'
                    Path   = $targetPath
                    Size   = $size
                    Status = 'WHAT IF'
                }
            } else {
                Write-Host "[CLEAR] Clearing: $targetPath  ($sizeStr)" -ForegroundColor Yellow
                try {
                    Get-ChildItem -LiteralPath $targetPath -Force | ForEach-Object {
                        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
                    }
                    Write-Host "[CLEARED] $targetPath" -ForegroundColor Green
                    $totalBytes += $size
                    $successCount++
                    $details += [pscustomobject]@{
                        Action = 'CLEAR'
                        Path   = $targetPath
                        Size   = $size
                        Status = 'OK'
                    }
                }
                catch {
                    Write-Error "Error clearing folder '$targetPath': $_"
                    $errorCount++
                    $details += [pscustomobject]@{
                        Action = 'CLEAR'
                        Path   = $targetPath
                        Size   = 0
                        Status = "ERROR: $($_.Exception.Message)"
                    }
                }
            }
        }
        
        "DELETE" {
            $size = Get-ItemSize $targetPath -Recurse
            $sizeStr = Format-ByteSize $size
            
            if ($WhatIf) {
                Write-Host "[WHAT IF] [DELETE] $targetPath  ($sizeStr)" -ForegroundColor DarkYellow
                $successCount++
                $totalBytes += $size
                $details += [pscustomobject]@{
                    Action = 'DELETE'
                    Path   = $targetPath
                    Size   = $size
                    Status = 'WHAT IF'
                }
            } else {
                Write-Host "[DELETE] Deleting: $targetPath  ($sizeStr)" -ForegroundColor Yellow
                try {
                    Remove-Item -LiteralPath $targetPath -Recurse -Force -ErrorAction Stop
                    Write-Host "[DELETED] $targetPath" -ForegroundColor Green
                    $totalBytes += $size
                    $successCount++
                    $details += [pscustomobject]@{
                        Action = 'DELETE'
                        Path   = $targetPath
                        Size   = $size
                        Status = 'OK'
                    }
                }
                catch {
                    Write-Error "Error deleting '$targetPath': $_"
                    $errorCount++
                    $details += [pscustomobject]@{
                        Action = 'DELETE'
                        Path   = $targetPath
                        Size   = 0
                        Status = "ERROR: $($_.Exception.Message)"
                    }
                }
            }
        }
    }
}

Write-Host "---------------------------------------------------"
Write-Host "Done. Success: $successCount, Errors/Skipped: $errorCount" -ForegroundColor Cyan
if ($successCount -gt 0) {
    Write-Host "Total size: $(Format-ByteSize $totalBytes)" -ForegroundColor Green
}

# Return structured result for aggregation by caller
return [pscustomobject]@{
    ComputerName = $env:COMPUTERNAME
    SuccessCount = $successCount
    ErrorCount   = $errorCount
    TotalBytes   = $totalBytes
    TotalSize    = Format-ByteSize $totalBytes
    Details      = $details
}