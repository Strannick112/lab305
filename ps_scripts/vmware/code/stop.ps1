# vmware_stop_vm.ps1
# Универсальный скрипт выключения ВМ с автопоиском файла .vmx

# ================= НАСТРОЙКИ =================
$vmrunPath = Get-Content "..\config\vm_path.txt"
$vmName = Get-Content "..\config\vm_name.txt"
$shutdownTimeoutSec = 120
$checkIntervalSec = 5
$forceStop = $true
# =============================================

Write-Host "=== Выключение ВМ на $env:COMPUTERNAME ===" -ForegroundColor Cyan

# Проверяем наличие vmrun.exe
if (-not (Test-Path $vmrunPath)) {
    Write-Error "vmrun.exe не найден по пути: $vmrunPath"
    exit 1
}

$vmxPath = Get-Content "..\config\vmx_path.txt"

# 1. Проверяем, запущена ли ВМ
Write-Host "1. Проверка состояния ВМ..." -ForegroundColor Yellow
$runningVMs = & $vmrunPath list 2>&1
$vmRunning = $runningVMs | Where-Object { $_ -match [regex]::Escape($vmxPath) }

if (-not $vmRunning) {
    Write-Host "   ВМ уже выключена. Нечего делать." -ForegroundColor Green
    exit 0
}

Write-Host "   ВМ запущена. Пытаюсь выключить..." -ForegroundColor Yellow

# 2. Мягкое выключение (ACPI shutdown)
Write-Host "2. Мягкое выключение (soft)..." -ForegroundColor Yellow
& $vmrunPath stop $vmxPath soft 2>&1 | Out-Null

# 3. Ждём, пока ВМ реально остановится
Write-Host "3. Ожидание остановки (до $shutdownTimeoutSec сек)..." -ForegroundColor Yellow
$elapsed = 0
$stopped = $false

while ($elapsed -lt $shutdownTimeoutSec) {
    Start-Sleep -Seconds $checkIntervalSec
    $elapsed += $checkIntervalSec
    
    $runningVMs = & $vmrunPath list 2>&1
    $vmRunning = $runningVMs | Where-Object { $_ -match [regex]::Escape($vmxPath) }
    
    if (-not $vmRunning) {
        $stopped = $true
        break
    }
    
    Write-Host "   ... прошло $elapsed сек, ВМ ещё работает" -ForegroundColor DarkGray
}

# 4. Если не выключилась — принудительно
if (-not $stopped) {
    if ($forceStop) {
        Write-Host "   Таймаут! Выполняю принудительное выключение (hard)..." -ForegroundColor Red
        & $vmrunPath stop $vmxPath hard 2>&1 | Out-Null
        Start-Sleep -Seconds 5
        
        $runningVMs = & $vmrunPath list 2>&1
        $vmRunning = $runningVMs | Where-Object { $_ -match [regex]::Escape($vmxPath) }
        
        if (-not $vmRunning) {
            Write-Host "   ВМ принудительно остановлена." -ForegroundColor Yellow
        } else {
            Write-Error "Не удалось выключить ВМ даже принудительно!"
            exit 1
        }
    } else {
        Write-Error "ВМ не выключилась за $shutdownTimeoutSec сек. Принудительное выключение отключено."
        exit 1
    }
}

Write-Host "`n✅ ВМ успешно выключена за $elapsed сек." -ForegroundColor Green