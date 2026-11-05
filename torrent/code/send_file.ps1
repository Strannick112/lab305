<#
.SYNOPSIS
    ˜˜˜˜˜˜˜˜ ˜˜˜˜˜˜˜˜˜ ˜˜˜˜ ˜˜ ˜˜˜ ˜˜˜˜˜˜˜˜ ˜˜˜˜˜˜˜˜˜˜.
.DESCRIPTION
    ˜˜˜˜˜˜ ˜˜˜˜ ˜˜˜˜˜˜˜˜, ˜˜˜˜˜˜˜˜ ˜˜˜ ˜ base64 ˜ ˜˜˜˜˜˜˜ ˜˜˜˜˜ WinRM.
    ˜˜ ˜˜˜˜˜˜˜˜ ˜˜˜˜˜˜˜ ˜˜˜˜˜˜˜˜˜˜ ˜ ˜˜˜˜˜˜˜˜˜ ˜˜ ˜˜˜˜˜˜˜˜˜˜ ˜˜˜˜.
.EXAMPLE
    # ˜˜˜˜˜˜˜˜˜˜ ˜˜˜˜˜˜˜-˜˜˜˜ ˜ ˜˜˜˜˜ Downloads ˜˜ ˜˜˜˜ ˜˜˜˜˜˜˜
    Invoke-RemoteCopyFile -LocalPath "C:\Users\Student\Desktop\shared\VM\demo305.torrent" -RemotePath "C:\Users\Student\Downloads\demo305.torrent"
.EXAMPLE
    # ˜˜˜˜˜˜˜˜˜˜ ˜˜˜˜ ˜ ˜˜˜˜˜˜˜˜˜˜˜ ˜˜˜˜˜ ˜ ˜˜˜˜˜˜˜˜˜ ˜˜˜˜˜
    Invoke-RemoteCopyFile -LocalPath ".\scripts\install.ps1" -RemoteFolder "C:\temp"
#>
function Invoke-RemoteCopyFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$LocalPath,

        # ˜˜˜˜˜˜ ˜˜˜˜ ˜˜ ˜˜˜˜˜˜˜˜ ˜˜˜˜˜˜ (˜ ˜˜˜˜˜˜ ˜˜˜˜˜)
        [string]$RemotePath,

        # ˜˜˜: ˜˜˜˜˜ ˜˜ ˜˜˜˜˜˜˜˜ ˜˜˜˜˜˜ (˜˜˜ ˜˜˜˜˜ ˜˜˜˜˜˜˜˜˜˜)
        [string]$RemoteFolder,

        [switch]$Force
    )

    if (-not $global:computers -or $global:computers.Count -eq 0) { throw "˜˜˜˜˜˜ ˜˜˜˜˜˜˜˜˜˜˜ ˜˜ ˜˜˜˜˜˜˜˜." }
    if (-not $global:cred) { throw "˜˜˜˜˜˜˜ ˜˜˜˜˜˜ ˜˜ ˜˜˜˜˜˜˜˜˜." }

    # ˜˜˜˜˜˜˜˜˜˜ ˜˜˜˜˜˜˜ ˜˜˜˜
    $fileName = [System.IO.Path]::GetFileName($LocalPath)
    if ($RemotePath) {
        $targetPath = $RemotePath
    } elseif ($RemoteFolder) {
        $targetPath = Join-Path $RemoteFolder $fileName
    } else {
        throw "˜˜˜˜˜˜˜ ˜˜˜˜ -RemotePath, ˜˜˜˜ -RemoteFolder"
    }

    # ˜˜˜˜˜˜ ˜˜˜˜ ˜˜˜˜˜˜˜˜ ˜ ˜˜˜˜˜˜˜˜ ˜ base64
    $fileBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $LocalPath))
    $fileSize = $fileBytes.Length
    $fileBase64 = [Convert]::ToBase64String($fileBytes)

    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "˜˜˜˜˜˜˜˜˜˜˜ ˜˜˜˜˜ ˜˜ $($global:computers.Count) ˜˜˜˜˜˜˜˜˜˜˜" -ForegroundColor Cyan
    Write-Host "˜˜˜˜˜˜˜˜ : $LocalPath" -ForegroundColor Cyan
    Write-Host "˜˜˜˜     : $targetPath" -ForegroundColor Cyan
    Write-Host "˜˜˜˜˜˜   : $([math]::Round($fileSize / 1KB, 2)) KB" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan

    if ($fileSize -gt 50MB) {
        Write-Warning "˜˜˜˜ ˜˜˜˜˜˜ 50 ˜˜. ˜˜˜˜˜˜˜˜ ˜˜˜˜˜ ˜˜˜˜˜˜ ˜˜˜˜˜."
    }

    $startTime = Get-Date

    $results = Invoke-Command -ComputerName $global:computers -Credential $global:cred -ScriptBlock {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $status = "OK"
        $error = $null

        try {
            # ˜˜˜˜˜˜ ˜˜˜˜˜, ˜˜˜˜ ˜ ˜˜˜
            $targetDir = Split-Path -Parent $using:targetPath
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }

            # ˜˜˜˜˜˜˜˜˜˜ base64 ˜ ˜˜˜˜˜˜˜˜˜ ˜˜˜˜
            $bytes = [Convert]::FromBase64String($using:fileBase64)
            [System.IO.File]::WriteAllBytes($using:targetPath, $bytes)

            # ˜˜˜˜˜˜˜˜˜, ˜˜˜ ˜˜˜˜ ˜˜˜˜˜˜˜˜˜˜˜˜˜ ˜˜˜˜˜˜
            if (-not (Test-Path $using:targetPath)) {
                throw "˜˜˜˜ ˜˜ ˜˜˜ ˜˜˜˜˜˜ ˜˜˜˜˜ ˜˜˜˜˜˜"
            }

            $actualSize = (Get-Item $using:targetPath).Length
            if ($actualSize -ne $bytes.Length) {
                throw "˜˜˜˜˜˜ ˜˜˜˜˜ ˜˜ ˜˜˜˜˜˜˜˜˜: ˜˜˜˜˜˜˜˜˜ $($bytes.Length), ˜˜˜˜˜˜˜˜ $actualSize"
            }
        }
        catch {
            $status = "FAIL"
            $error = $_.Exception.Message
        }
        finally {
            $sw.Stop()
        }

        [pscustomobject]@{
            ComputerName = $env:COMPUTERNAME
            Status       = $status
            Error        = $error
            Size         = $using:fileSize
            DurationSec  = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        }
    } -AsJob -ThrottleLimit 32 -ErrorAction Stop |
        Wait-Job |
        Receive-Job

    $totalTime = (Get-Date) - $startTime

    # ============ ˜˜?˜ ============
    Write-Host "`n===================================================" -ForegroundColor Cyan
    Write-Host "˜˜?˜ ˜ ˜˜˜˜˜˜˜˜˜˜˜" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan

    $okCount   = ($results | Where-Object { $_.Status -eq "OK" }).Count
    $failCount = ($results | Where-Object { $_.Status -eq "FAIL" }).Count

    foreach ($r in $results) {
        $color = if ($r.Status -eq "OK") { "Green" } else { "Red" }
        Write-Host ("{0,-20} [{1}] {2} ˜˜˜" -f $r.ComputerName, $r.Status, $r.DurationSec) -ForegroundColor $color
        if ($r.Error) {
            Write-Host "    ˜˜˜˜˜˜: $($r.Error)" -ForegroundColor Red
        }
    }

    Write-Host "---------------------------------------------------"
    Write-Host "˜˜˜˜˜: $($results.Count) | OK: $okCount | FAIL: $failCount | ˜˜˜˜˜: $([math]::Round($totalTime.TotalSeconds, 1)) ˜˜˜" -ForegroundColor Cyan

    return $results
}