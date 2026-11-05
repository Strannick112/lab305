# Загружаем учетные данные$username = Get-Content ".\credentials\username.txt"$password = Get-Content ".\credentials\password.txt" | ConvertTo-SecureString$global:cred = New-Object System.Management.Automation.PSCredential($username, $password)$CleanScriptPath = ".\clean_folders.ps1"$CleanPathsFile  = ".\config\path_for_clean.txt"# Загружаем список компьютеров$global:computers = Get-Content ".\config\computers.txt"Write-Host "? Загружено $($computers.Count) компьютеров" -ForegroundColor GreenWrite-Host "Используйте: Invoke-OnAll { ваш_скрипт }" -ForegroundColor CyanWrite-Host "Или: Invoke-OnOne 'ip' { ваш_скрипт }" -ForegroundColor Cyan# Функция для выполнения на ОДНОМ компьютереfunction Invoke-OnOne {    param(        [string]$ComputerName,        [scriptblock]$ScriptBlock    )    Invoke-Command -ComputerName $ComputerName -Credential $cred -ScriptBlock $ScriptBlock}# Функция для выполнения на ВСЕХ компьютерахfunction Invoke-OnAll {    param(        [scriptblock]$ScriptBlock    )    Invoke-Command -ComputerName $computers -Credential $cred -ScriptBlock $ScriptBlock}function Invoke-RemoteClean {    [CmdletBinding()]    param(        [string]$ScriptPath = $CleanScriptPath,        [string]$PathsFile  = $CleanPathsFile,        [switch]$WhatIf    )    if (-not (Test-Path $ScriptPath)) { throw "Script not found: $ScriptPath" }    if (-not (Test-Path $PathsFile))  { throw "Paths file not found: $PathsFile" }    $scriptCode = Get-Content -Path $ScriptPath -Raw    $pathsCode  = Get-Content -Path $PathsFile  -Raw    $whatIfFlag = $WhatIf.IsPresent    Write-Host "Starting cleanup on all computers..." -ForegroundColor Cyan    if ($whatIfFlag) { Write-Host "Mode: WHAT IF (preview only, no deletion)" -ForegroundColor Yellow }    $results = Invoke-OnAll {        $sb = [ScriptBlock]::Create($using:scriptCode)        $tempPaths = "$env:TEMP\paths_for_clean_$([guid]::NewGuid().ToString('N')).txt"        $using:pathsCode | Set-Content -LiteralPath $tempPaths -Encoding UTF8                try {            if ($using:whatIfFlag) {                & $sb -FilePath $tempPaths -WhatIf            } else {                & $sb -FilePath $tempPaths            }        }        finally {            Remove-Item -LiteralPath $tempPaths -Force -ErrorAction SilentlyContinue        }    }    # Aggregate summary across all computers    Write-Host "`n===================================================" -ForegroundColor Cyan    Write-Host "AGGREGATE SUMMARY" -ForegroundColor Cyan    Write-Host "===================================================" -ForegroundColor Cyan    $grandBytes   = [long]0    $grandSuccess = 0    $grandErrors  = 0    foreach ($r in $results) {        $grandBytes   += [long]$r.TotalBytes        $grandSuccess += [int]$r.SuccessCount        $grandErrors  += [int]$r.ErrorCount        Write-Host ("{0,-20} OK: {1,3}  ERR: {2,3}  Freed: {3}" -f            $r.ComputerName, $r.SuccessCount, $r.ErrorCount, $r.TotalSize)    }    Write-Host "---------------------------------------------------"    if (-not $whatIfFlag) {        $sizeStr = if ($grandBytes -ge 1GB) { "{0:N2} GB" -f ($grandBytes / 1GB) }                   elseif ($grandBytes -ge 1MB) { "{0:N2} MB" -f ($grandBytes / 1MB) }                   elseif ($grandBytes -ge 1KB) { "{0:N2} KB" -f ($grandBytes / 1KB) }                   else { "$grandBytes B" }        Write-Host "TOTAL across all computers: OK=$grandSuccess, ERR=$grandErrors, Freed=$sizeStr" -ForegroundColor Green    } else {        Write-Host "Preview complete. No data was deleted." -ForegroundColor Yellow    }}function Invoke-RemoteScriptFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LocalFolder,

        [Parameter(Mandatory = $true)]
        [string]$ScriptName,

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
    Write-Host "ПАРАЛЛЕЛЬНЫЙ запуск скрипта на $($global:computers.Count) машинах" -ForegroundColor Cyan
    Write-Host "Папка      : $LocalFolder" -ForegroundColor Cyan
    Write-Host "Скрипт     : $ScriptName" -ForegroundColor Cyan
    Write-Host "Цель       : $RemoteFolder\$localFolderName" -ForegroundColor Cyan
    Write-Host "Параллелизм: $ThrottleLimit машин одновременно" -ForegroundColor Cyan
    if ($Arguments.Count -gt 0) {
        Write-Host "Параметры  :" -ForegroundColor Cyan
        $Arguments.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Key) = $($_.Value)" }
    }
    Write-Host "===================================================" -ForegroundColor Cyan

    $startTime = Get-Date
    $sessions = @()

    try {
        # 1. СОЗДАЁМ ВСЕ СЕССИИ ОДНОВРЕМЕННО
        Write-Host "`n📡 Устанавливаю соединения со всеми компьютерами..." -ForegroundColor Yellow
        $sessions = New-PSSession -ComputerName $global:computers -Credential $global:cred -ErrorAction SilentlyContinue
        
        $failedComputers = $global:computers | Where-Object { 
            $_ -notin ($sessions | ForEach-Object { $_.ComputerName }) 
        }
        
        if ($sessions.Count -eq 0) { throw "Не удалось подключиться ни к одному компьютеру" }
        
        Write-Host "✅ Подключено: $($sessions.Count) из $($global:computers.Count)" -ForegroundColor Green
        if ($failedComputers.Count -gt 0) {
            Write-Host "⚠️  Недоступны: $($failedComputers -join ', ')" -ForegroundColor Yellow
        }

        # 2. КОПИРУЕМ ПАПКУ НА ВСЕ МАШИНЫ
        Write-Host "`n📤 Копирую файлы на все машины..." -ForegroundColor Yellow
        foreach ($session in $sessions) {
            try {
                Copy-Item -Path $LocalFolder -Destination $RemoteFolder -ToSession $session -Recurse -Force -ErrorAction Stop
                Write-Host "   ✅ $($session.ComputerName)" -ForegroundColor DarkGreen
            } catch {
                Write-Warning "   ❌ $($session.ComputerName): $($_.Exception.Message)"
            }
        }

        # 3. ЗАПУСКАЕМ СКРИПТ НА ВСЕХ МАШИНАХ ОДНОВРЕМЕННО
        Write-Host "`n🚀 Запускаю скрипт на всех машинах (параллельно)..." -ForegroundColor Yellow
        $runResults = Invoke-Command -Session $sessions -ScriptBlock {
            param($remoteFolder, $localFolderName, $scriptName, $args_, $doCleanup)
            
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $exitCode = 0
            $output = $null
            $errors = @()

            try {
                $scriptFolder = Join-Path $remoteFolder $localFolderName
                $scriptPath = Join-Path $scriptFolder $scriptName
                
                if (-not (Test-Path $scriptPath)) {
                    throw "Скрипт не найден: $scriptPath"
                }

                Set-Location $scriptFolder

                # 🔑 ИСПРАВЛЕНИЕ: Обход Execution Policy через запуск нового процесса с флагом Bypass
                $psExe = "powershell.exe"
                $cmdParts = @("& '$scriptPath'")
                
                # Формируем аргументы командной строки из хеш-таблицы
                if ($args_.Count -gt 0) {
                    foreach ($key in $args_.Keys) {
                        $val = $args_[$key]
                        # Безопасно экранируем строковые значения
                        if ($val -is [string]) {
                            $val = "'$($val -replace "'", "''")'"
                        }
                        $cmdParts += "-$key $val"
                    }
                }
                
                $commandLine = $cmdParts -join " "
                
                # Выполняем команду с принудительным обходом политики выполнения
                $output = & $psExe -NoProfile -ExecutionPolicy Bypass -Command $commandLine 2>&1
                $exitCode = $LASTEXITCODE
            }
            catch {
                $exitCode = 1
                $errors += $_.Exception.Message
            }
            finally {
                $sw.Stop()
                
                # Очистка после выполнения
                if ($doCleanup) {
                    $scriptFolder = Join-Path $remoteFolder $localFolderName
                    Remove-Item -LiteralPath $scriptFolder -Recurse -Force -ErrorAction SilentlyContinue
                }
            }

            [pscustomobject]@{
                ComputerName = $env:COMPUTERNAME
                ExitCode     = $exitCode
                Output       = ($output | Out-String)
                Errors       = ($errors | Out-String)
                DurationSec  = [math]::Round($sw.Elapsed.TotalSeconds, 2)
                Status       = if ($exitCode -eq 0) { "OK" } else { "FAIL" }
            }
        } -ArgumentList $RemoteFolder, $localFolderName, $ScriptName, $Arguments, $Cleanup.IsPresent -ThrottleLimit $ThrottleLimit

        # 4. ОТЧЁТ
        $totalTime = (Get-Date) - $startTime

        Write-Host "`n===================================================" -ForegroundColor Cyan
        Write-Host "ОТЧЁТ О ВЫПОЛНЕНИИ" -ForegroundColor Cyan
        Write-Host "===================================================" -ForegroundColor Cyan

        $okCount   = ($runResults | Where-Object { $_.Status -eq "OK" }).Count
        $failCount = ($runResults | Where-Object { $_.Status -eq "FAIL" }).Count

        foreach ($r in $runResults) {
            $color = if ($r.Status -eq "OK") { "Green" } else { "Red" }
            Write-Host ("{0,-20} [{1}] {2} сек" -f $r.ComputerName, $r.Status, $r.DurationSec) -ForegroundColor $color
            if ($r.Output -and $r.Output.Trim()) {
                $r.Output -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            }
            if ($r.Errors -and $r.Errors.Trim()) {
                $r.Errors -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { Write-Host "    ОШИБКА: $_" -ForegroundColor Red }
            }
        }

        Write-Host "---------------------------------------------------"
        Write-Host "Всего: $($runResults.Count) | OK: $okCount | FAIL: $failCount" -ForegroundColor Cyan
        Write-Host "Общее время: $([math]::Round($totalTime.TotalSeconds, 1)) сек" -ForegroundColor Cyan

        return $runResults
    }
    finally {
        if ($sessions.Count -gt 0) {
            $sessions | Remove-PSSession -ErrorAction SilentlyContinue
        }
    }
}