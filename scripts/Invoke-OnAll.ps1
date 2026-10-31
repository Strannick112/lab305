# Загружаем учетные данные
$username = Get-Content ".\credentials\username.txt"
$password = Get-Content ".\credentials\password.txt" | ConvertTo-SecureString
$global:cred = New-Object System.Management.Automation.PSCredential($username, $password)

# Загружаем список компьютеров
$global:computers = Get-Content ".\config\computers.txt"

$CleanScriptPath = ".\config\clean_folders.ps1"
$CleanPathsFile = ".\config\path_for_clean.txt"

Write-Host "? Загружено $($computers.Count) компьютеров" -ForegroundColor Green
Write-Host "Используйте: Invoke-OnAll { ваш_скрипт }" -ForegroundColor Cyan
Write-Host "Или: Invoke-OnOne 'ip' { ваш_скрипт }" -ForegroundColor Cyan

# Функция для выполнения на ОДНОМ компьютере
function Invoke-OnOne {
    param(
        [string]$ComputerName,
        [scriptblock]$ScriptBlock
    )
    Invoke-Command -ComputerName $ComputerName -Credential $cred -ScriptBlock $ScriptBlock
}

# Функция для выполнения на ВСЕХ компьютерах
function Invoke-OnAll {
    param(
        [scriptblock]$ScriptBlock
    )
    Invoke-Command -ComputerName $computers -Credential $cred -ScriptBlock $ScriptBlock
}

function Invoke-RemoteClean {
    [CmdletBinding()]
    param(
        [string]$ScriptPath = $CleanScriptPath,
        [string]$PathsFile  = $CleanPathsFile,
        [switch]$WhatIf
    )

    if (-not (Test-Path $ScriptPath)) { throw "Script not found: $ScriptPath" }
    if (-not (Test-Path $PathsFile))  { throw "Paths file not found: $PathsFile" }

    $scriptCode = Get-Content -Path $ScriptPath -Raw
    $pathsCode  = Get-Content -Path $PathsFile  -Raw
    $whatIfFlag = $WhatIf.IsPresent

    Write-Host "Starting cleanup on all computers..." -ForegroundColor Cyan
    if ($whatIfFlag) { Write-Host "Mode: WHAT IF (preview only, no deletion)" -ForegroundColor Yellow }

    $results = Invoke-OnAll {
        $sb = [ScriptBlock]::Create($using:scriptCode)
        $tempPaths = "$env:TEMP\paths_for_clean_$([guid]::NewGuid().ToString('N')).txt"
        $using:pathsCode | Set-Content -LiteralPath $tempPaths -Encoding UTF8
        
        try {
            if ($using:whatIfFlag) {
                & $sb -FilePath $tempPaths -WhatIf
            } else {
                & $sb -FilePath $tempPaths
            }
        }
        finally {
            Remove-Item -LiteralPath $tempPaths -Force -ErrorAction SilentlyContinue
        }
    }

    # Aggregate summary across all computers
    Write-Host "`n===================================================" -ForegroundColor Cyan
    Write-Host "AGGREGATE SUMMARY" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan

    $grandBytes   = [long]0
    $grandSuccess = 0
    $grandErrors  = 0

    foreach ($r in $results) {
        $grandBytes   += [long]$r.TotalBytes
        $grandSuccess += [int]$r.SuccessCount
        $grandErrors  += [int]$r.ErrorCount
        Write-Host ("{0,-20} OK: {1,3}  ERR: {2,3}  Freed: {3}" -f
            $r.ComputerName, $r.SuccessCount, $r.ErrorCount, $r.TotalSize)
    }

    Write-Host "---------------------------------------------------"
    if (-not $whatIfFlag) {
        $sizeStr = if ($grandBytes -ge 1GB) { "{0:N2} GB" -f ($grandBytes / 1GB) }
                   elseif ($grandBytes -ge 1MB) { "{0:N2} MB" -f ($grandBytes / 1MB) }
                   elseif ($grandBytes -ge 1KB) { "{0:N2} KB" -f ($grandBytes / 1KB) }
                   else { "$grandBytes B" }
        Write-Host "TOTAL across all computers: OK=$grandSuccess, ERR=$grandErrors, Freed=$sizeStr" -ForegroundColor Green
    } else {
        Write-Host "Preview complete. No data was deleted." -ForegroundColor Yellow
    }
}