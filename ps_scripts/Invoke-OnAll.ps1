# Загружаем учетные данные
$username = Get-Content "$PSScriptRoot\credentials\username.txt"
$password = Get-Content "$PSScriptRoot\credentials\password.txt" | ConvertTo-SecureString
$global:cred = New-Object System.Management.Automation.PSCredential($username, $password)

$CleanScriptPath = "$PSScriptRoot\manage\code\clean_folders.ps1"
$CleanPathsFile  = "$PSScriptRoot\config\path_for_clean.txt"

# Загружаем список компьютеров
$global:computers = (Import-Csv "$PSScriptRoot\config\pcs.csv").ip

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

function Invoke-RemoteScriptFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LocalFolder,
        [Parameter(Mandatory = $true)][string]$ScriptName,
        [string]$RemoteFolder = "C:\temp\remote_scripts",
        [hashtable]$Arguments = @{},
        [switch]$Cleanup,
        [int]$ThrottleLimit = 32
    )

    if (-not (Test-Path $LocalFolder)) { throw "Папка не найдена: $LocalFolder" }
    if (-not $global:computers -or $global:computers.Count -eq 0) { throw "Список компьютеров не загружен." }
    if (-not $global:cred) { throw "Учётные данные не загружены." }

    $localFolderName = Split-Path $LocalFolder -Leaf

    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "Запуск на $($global:computers.Count) машинах" -ForegroundColor Cyan
    Write-Host "Папка  : $LocalFolder" -ForegroundColor Cyan
    Write-Host "Скрипт : $ScriptName" -ForegroundColor Cyan
    Write-Host "Цель   : $RemoteFolder\$localFolderName" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan

    $startTime = Get-Date
    $sessions = @()

    try {
        Write-Host "`nУстанавливаю соединения..." -ForegroundColor Yellow
        $sessions = New-PSSession -ComputerName $global:computers -Credential $global:cred -Authentication Negotiate -ErrorAction SilentlyContinue
        if ($sessions.Count -eq 0) { throw "Не удалось подключиться ни к одному компьютеру" }

        $failed = $global:computers | Where-Object { $_ -notin $sessions.ComputerName }
        Write-Host "Подключено: $($sessions.Count) из $($global:computers.Count)" -ForegroundColor Green
        if ($failed) { Write-Host "Недоступны: $($failed -join ', ')" -ForegroundColor Yellow }

        Write-Host "`nКопирую файлы..." -ForegroundColor Yellow
        foreach ($s in $sessions) {
            try {
                Copy-Item -Path $LocalFolder -Destination $RemoteFolder -ToSession $s -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Warning "   $($s.ComputerName): $($_.Exception.Message)"
            }
        }

        Write-Host "`nВыполняю скрипт..." -ForegroundColor Yellow
        $runResults = Invoke-Command -Session $sessions -ThrottleLimit $ThrottleLimit `
            -ArgumentList $RemoteFolder, $localFolderName, $ScriptName, $Arguments, $Cleanup.IsPresent `
            -ScriptBlock {
                param($remoteFolder, $localFolderName, $scriptName, $args_, $doCleanup)

                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $exitCode = 0
                $out = New-Object System.Collections.Generic.List[string]
                $err = New-Object System.Collections.Generic.List[string]
                $scriptFolder = Join-Path $remoteFolder $localFolderName

                try {
                    $scriptPath = Join-Path $scriptFolder $scriptName
                    if (-not (Test-Path -LiteralPath $scriptPath)) { throw "Скрипт не найден: $scriptPath" }
                    Set-Location -LiteralPath $scriptFolder

                    # обход ExecutionPolicy без дочернего процесса
                    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
                    $global:LASTEXITCODE = 0

                    # КЛЮЧЕВОЕ: выполняем скрипт в этой же сессии.
                    # Никакого powershell.exe, никакого консольного пайпа, никакого перекодирования.
                    # *>&1 забирает все потоки, включая Write-Host (Information).
                    & $scriptPath @args_ *>&1 | ForEach-Object {
                        if ($_ -is [System.Management.Automation.ErrorRecord]) {
                            $err.Add($_.Exception.Message)
                        }
                        elseif ($_ -is [System.Management.Automation.WarningRecord]) {
                            $out.Add("WARNING: $($_.Message)")
                        }
                        elseif ($_ -is [System.Management.Automation.InformationRecord]) {
                            $out.Add([string]$_.MessageData)
                        }
                        else {
                            $out.Add([string]$_)
                        }
                    }

                    if ($LASTEXITCODE) { $exitCode = $LASTEXITCODE }
                }
                catch {
                    $exitCode = 1
                    $err.Add($_.Exception.Message)
                }
                finally {
                    $sw.Stop()
                    if ($doCleanup) {
                        Remove-Item -LiteralPath $scriptFolder -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }

                [pscustomobject]@{
                    ComputerName = $env:COMPUTERNAME
                    ExitCode     = $exitCode
                    Output       = ($out -join "`r`n")
                    Errors       = ($err -join "`r`n")
                    DurationSec  = [math]::Round($sw.Elapsed.TotalSeconds, 2)
                    Status       = if ($exitCode -eq 0) { "OK" } else { "FAIL" }
                }
            }

        $totalTime = (Get-Date) - $startTime
        Write-Host "`n===================================================" -ForegroundColor Cyan
        Write-Host "ОТЧЁТ О ВЫПОЛНЕНИИ" -ForegroundColor Cyan
        Write-Host "===================================================" -ForegroundColor Cyan

        $okCount   = @($runResults | Where-Object Status -eq 'OK').Count
        $failCount = @($runResults | Where-Object Status -eq 'FAIL').Count

        foreach ($r in $runResults) {
            $color = if ($r.Status -eq "OK") { "Green" } else { "Red" }
            Write-Host ("{0,-20} [{1}] {2} сек" -f $r.ComputerName, $r.Status, $r.DurationSec) -ForegroundColor $color
            if ($r.Output) {
                $r.Output -split "`r?`n" | Where-Object { $_.Trim() } | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            }
            if ($r.Errors) {
                $r.Errors -split "`r?`n" | Where-Object { $_.Trim() } | ForEach-Object { Write-Host "    ОШИБКА: $_" -ForegroundColor Red }
            }
        }

        Write-Host "---------------------------------------------------"
        Write-Host "Всего: $($runResults.Count) | OK: $okCount | FAIL: $failCount | Время: $([math]::Round($totalTime.TotalSeconds, 1)) сек" -ForegroundColor Cyan
        return $runResults
    }
    finally {
        if ($sessions.Count -gt 0) { $sessions | Remove-PSSession -ErrorAction SilentlyContinue }
    }
}