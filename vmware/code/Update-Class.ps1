#Requires -RunAsAdministrator
# =====================================================================
# Update-Classroom.ps1
# Запускается НА СЕРВЕРЕ (там же, где лежит эталонная ВМ).
# Рассылает дельты снапшота на все клиентские ПК через robocopy (push)
# и применяет снапшот через Invoke-OnAll (WinRM).
# =====================================================================

param(
    [string]$SnapshotName = "Ocrober2026update",
    [string]$VmName       = Get-Content "..\config\vm_name.txt",
    [switch]$WhatIf,
    [switch]$SkipStop,
    [switch]$SkipRevert,
    [switch]$SkipChecks
)

$Host.UI.RawUI.WindowTitle = "Обновление ВМ в аудитории"
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------- 1. Подключаем вашу инфраструктуру ----------
. "$PSScriptRoot\Invoke-OnAll.ps1"

# ---------- 2. Настройки ----------
$ServerVmPath = "C:\Users\Student\Documents\Virtual Machines\$VmName"                      # локальный путь к ВМ НА СЕРВЕРЕ
$LocalVmDir   = "C:\Users\Student\Documents\Virtual Machines\$VmName"                      # путь к ВМ на клиентах
$LocalVmx     = "$LocalVmDir\$VmName.vmx"
$Vmrun        = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"

# Файлы дельт снапшота (БАЗОВЫЙ .vmdk НЕ включаем — он и так одинаков на всех!)
$DeltaFiles = @(
    "$VmName-000001.vmdk",
    "$VmName-000002.vmdk",
    "$VmName-000003.vmdk",
    "$VmName-000004.vmdk",
    "$VmName-000005.vmdk",
    "$VmName-000001.vmsn",
    "$VmName-000002.vmsn",
    "$VmName-000003.vmsn",
    "$VmName-000004.vmsn",
    "$VmName-000005.vmsn",
    "$VmName.vmsd",
    "$VmName.vmx"
)

# ---------- 3. Вспомогательные функции ----------
function Write-Step($text) {
    Write-Host ""
    Write-Host ("=== {0} ===" -f $text) -ForegroundColor Cyan
}

# ---------- 4. ПРЕДВАРИТЕЛЬНЫЕ ПРОВЕРКИ (на сервере) ----------
if (-not $SkipChecks) {
    Write-Step "0. Проверка готовности сервера"

    # 4.1. ВМ на сервере должна быть выключена
    $runningVMs = & $Vmrun list 2>&1
    if ($runningVMs -match [regex]::Escape("$ServerVmPath\$VmName.vmx")) {
        throw "❌ Эталонная ВМ на сервере запущена! Сначала выключите её (Shut Down из гостевой ОС)."
    }
    Write-Host "  ✅ Эталонная ВМ выключена" -ForegroundColor Green

    # 4.2. Файлы дельты должны существовать
    $missing = @()
    foreach ($f in $DeltaFiles) {
        $full = Join-Path $ServerVmPath $f
        if (-not (Test-Path $full)) { $missing += $f }
    }
    if ($missing.Count -gt 0) {
        Write-Host "  ⚠️  Отсутствуют файлы (будут пропущены при копировании):" -ForegroundColor Yellow
        $missing | ForEach-Object { Write-Host "      $_" -ForegroundColor Yellow }
        # Оставляем только реально существующие
        $DeltaFiles = $DeltaFiles | Where-Object { Test-Path (Join-Path $ServerVmPath $_) }
        if ($DeltaFiles.Count -eq 0) {
            throw "❌ Нет ни одного файла дельты для рассылки. Проверьте снапшот '$SnapshotName'."
        }
    } else {
        Write-Host "  ✅ Все файлы дельты найдены: $($DeltaFiles.Count) шт." -ForegroundColor Green
    }

    # 4.3. Снапшот существует на сервере
    $snaps = & $Vmrun listSnapshots "$ServerVmPath\$VmName.vmx" 2>&1
    if (-not ($snaps -match [regex]::Escape($SnapshotName))) {
        throw "❌ Снапшот '$SnapshotName' не найден на сервере. Доступные: $snaps"
    }
    Write-Host "  ✅ Снапшот '$SnapshotName' найден на сервере" -ForegroundColor Green
}

# ---------- 5. Остановка ВМ на всех клиентах ----------
if (-not $SkipStop) {
    Write-Step "1. Остановка ВМ на всех клиентах"
    if ($WhatIf) {
        Write-Host "[WHATIF] Будет выполнена: vmrun stop на всех ПК" -ForegroundColor Yellow
    } else {
        $stopResults = Invoke-OnAll {
            $vmrun = $using:Vmrun
            $vmx   = $using:LocalVmx
            if (Test-Path $vmx) {
                try {
                    $null = & $vmrun stop $vmx soft nogui 2>&1
                    [pscustomobject]@{ ComputerName=$env:COMPUTERNAME; Status="STOPPED" }
                } catch {
                    [pscustomobject]@{ ComputerName=$env:COMPUTERNAME; Status="ERR_STOP"; Detail=$_.Exception.Message }
                }
            } else {
                [pscustomobject]@{ ComputerName=$env:COMPUTERNAME; Status="NO_VMX" }
            }
        }
        $stopped = ($stopResults | Where-Object Status -eq "STOPPED").Count
        $errs    = ($stopResults | Where-Object Status -like "ERR*").Count
        Write-Host "  Остановлено: $stopped | Ошибок: $errs" -ForegroundColor Green
        if ($errs -gt 0) { $stopResults | Where-Object Status -like "ERR*" | Format-Table -AutoSize }
    }
}

# ---------- 6. Рассылка файлов дельты (push с сервера на клиенты) ----------
Write-Step "2. Рассылка файлов снапшота (robocopy, push)"
if ($WhatIf) {
    Write-Host "[WHATIF] Источник (локально на сервере): $ServerVmPath" -ForegroundColor Yellow
    Write-Host "[WHATIF] Файлы к рассылке:" -ForegroundColor Yellow
    $DeltaFiles | ForEach-Object { Write-Host "    $_" }
    Write-Host "[WHATIF] Целевые ПК: $($global:computers.Count) шт." -ForegroundColor Yellow
} else {
    $jobs = foreach ($pc in $global:computers) {
        Start-Job -Name "copy-$pc" -ScriptBlock {
            param($pc, $src, $dst, $files)
            if (-not (Test-Connection $pc -Count 1 -Quiet)) {
                return [pscustomobject]@{ PC=$pc; Status="OFFLINE"; Bytes=0 }
            }
            $target = "\\$pc\C`$\VMs\$($dst -replace '.*\\','')"
            # robocopy читает С ЛОКАЛЬНОГО ДИСКА СЕРВЕРА, пишет на клиент
            $argList = @($src, $target) + $files + @("/R:2","/W:3","/NP","/NFL","/NDL","/NJH","/NJS")
            $rc = & robocopy @argList
            $bytes = 0
            $rc | Select-String "Total\s*:\s*(\d+)" | ForEach-Object {
                $bytes = [long]$_.Matches[0].Groups[1].Value
            }
            $status = if ($LASTEXITCODE -lt 8) { "OK" } else { "ERR_$LASTEXITCODE" }
            [pscustomobject]@{ PC=$pc; Status=$status; Bytes=$bytes }
        } -ArgumentList $pc, $ServerVmPath, $LocalVmDir, $DeltaFiles
    }

    # Прогресс
    do {
        $running = ($jobs | Where-Object State -eq Running).Count
        $done    = ($jobs | Where-Object State -eq Completed).Count
        Write-Host "`r  Выполняется: $running | Завершено: $done / $($jobs.Count)   " -NoNewline
        Start-Sleep -Seconds 2
    } while ($running -gt 0)
    Write-Host ""

    $results = $jobs | Receive-Job
    $jobs | Remove-Job -Force

    $ok    = ($results | Where-Object Status -eq "OK").Count
    $err   = ($results | Where-Object Status -like "ERR*").Count
    $off   = ($results | Where-Object Status -eq "OFFLINE").Count
    $totalBytes = ($results | Measure-Object Bytes -Sum).Sum
    $sizeStr = if ($totalBytes -ge 1GB) { "{0:N2} GB" -f ($totalBytes/1GB) }
               elseif ($totalBytes -ge 1MB) { "{0:N2} MB" -f ($totalBytes/1MB) }
               else { "$totalBytes B" }

    Write-Host "  ИТОГО: OK=$ok | Ошибок=$err | Недоступно=$off | Передано=$sizeStr" -ForegroundColor Green
    if ($err -gt 0 -or $off -gt 0) {
        Write-Host "  Проблемные машины:" -ForegroundColor Yellow
        $results | Where-Object Status -ne "OK" | Format-Table -AutoSize
    }
}

# ---------- 7. Применение снапшота на клиентах ----------
if (-not $SkipRevert) {
    Write-Step "3. Применение снапшота '$SnapshotName' на всех клиентах"
    if ($WhatIf) {
        Write-Host "[WHATIF] Будет выполнена: vmrun revertToSnapshot '$SnapshotName'" -ForegroundColor Yellow
    } else {
        $revertResults = Invoke-OnAll {
            $vmrun = $using:Vmrun
            $vmx   = $using:LocalVmx
            $snap  = $using:SnapshotName
            try {
                $null = & $vmrun revertToSnapshot $vmx $snap nogui 2>&1
                [pscustomobject]@{ ComputerName=$env:COMPUTERNAME; Status="REVERTED" }
            } catch {
                [pscustomobject]@{ ComputerName=$env:COMPUTERNAME; Status="ERR_REVERT"; Detail=$_.Exception.Message }
            }
        }
        $reverted = ($revertResults | Where-Object Status -eq "REVERTED").Count
        $errors   = ($revertResults | Where-Object Status -like "ERR*").Count
        Write-Host "  Успешно: $reverted | Ошибок: $errors" -ForegroundColor Green
        if ($errors -gt 0) {
            $revertResults | Where-Object Status -like "ERR*" | Format-Table -AutoSize
        }
    }
}

# ---------- 8. Финал ----------
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " ГОТОВО. Аудитория обновлена." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Read-Host "Нажмите Enter для выхода"