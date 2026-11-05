<#
.SYNOPSIS
    Копирует локальный файл на все удалённые компьютеры.
.DESCRIPTION
    Читает файл локально, кодирует его в base64 и передаёт через WinRM.
    На удалённых машинах декодирует и сохраняет по указанному пути.
.EXAMPLE
    # Копировать торрент-файл в папку Downloads на всех машинах
    Invoke-RemoteCopyFile -LocalPath "C:\Users\Student\Desktop\shared\VM\demo305.torrent" -RemotePath "C:\Users\Student\Downloads\demo305.torrent"
.EXAMPLE
    # Копировать файл с сохранением имени в указанную папку
    Invoke-RemoteCopyFile -LocalPath ".\scripts\install.ps1" -RemoteFolder "C:\temp"
#>

function Invoke-RemoteCopyFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$LocalPath,

        # Полный путь на удалённой машине (с именем файла)
        [string]$RemotePath,

        # ИЛИ: папка на удалённой машине (имя файла сохранится)
        [string]$RemoteFolder,

        [switch]$Force
    )

    if (-not $global:computers -or $global:computers.Count -eq 0) { throw "Список компьютеров не загружен." }
    if (-not $global:cred) { throw "Учётные данные не загружены." }

    # Определяем целевой путь
    $fileName = [System.IO.Path]::GetFileName($LocalPath)
    if ($RemotePath) {
        $targetPath = $RemotePath
    } elseif ($RemoteFolder) {
        $targetPath = Join-Path $RemoteFolder $fileName
    } else {
        throw "Укажите либо -RemotePath, либо -RemoteFolder"
    }

    # Читаем файл локально и кодируем в base64
    $fileBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $LocalPath))
    $fileSize = $fileBytes.Length
    $fileBase64 = [Convert]::ToBase64String($fileBytes)

    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "Копирование файла на $($global:computers.Count) компьютеров" -ForegroundColor Cyan
    Write-Host "Источник : $LocalPath" -ForegroundColor Cyan
    Write-Host "Цель     : $targetPath" -ForegroundColor Cyan
    Write-Host "Размер   : $([math]::Round($fileSize / 1KB, 2)) KB" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan

    if ($fileSize -gt 50MB) {
        Write-Warning "Файл больше 50 МБ. Передача может занять время."
    }

    $startTime = Get-Date

    $results = Invoke-Command -ComputerName $global:computers -Credential $global:cred -ScriptBlock {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $status = "OK"
        $error = $null

        try {
            # Создаём папку, если её нет
            $targetDir = Split-Path -Parent $using:targetPath
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }

            # Декодируем base64 и сохраняем файл
            $bytes = [Convert]::FromBase64String($using:fileBase64)
            [System.IO.File]::WriteAllBytes($using:targetPath, $bytes)

            # Проверяем, что файл действительно создан
            if (-not (Test-Path $using:targetPath)) {
                throw "Файл не был создан после записи"
            }

            $actualSize = (Get-Item $using:targetPath).Length
            if ($actualSize -ne $bytes.Length) {
                throw "Размер файла не совпадает: ожидалось $($bytes.Length), получено $actualSize"
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

    # ============ ОТЧЁТ ============
    Write-Host "`n===================================================" -ForegroundColor Cyan
    Write-Host "ОТЧЁТ О КОПИРОВАНИИ" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan

    $okCount   = ($results | Where-Object { $_.Status -eq "OK" }).Count
    $failCount = ($results | Where-Object { $_.Status -eq "FAIL" }).Count

    foreach ($r in $results) {
        $color = if ($r.Status -eq "OK") { "Green" } else { "Red" }
        Write-Host ("{0,-20} [{1}] {2} сек" -f $r.ComputerName, $r.Status, $r.DurationSec) -ForegroundColor $color
        if ($r.Error) {
            Write-Host "    ОШИБКА: $($r.Error)" -ForegroundColor Red
        }
    }

    Write-Host "---------------------------------------------------"
    Write-Host "Всего: $($results.Count) | OK: $okCount | FAIL: $failCount | Время: $([math]::Round($totalTime.TotalSeconds, 1)) сек" -ForegroundColor Cyan

    return $results
}