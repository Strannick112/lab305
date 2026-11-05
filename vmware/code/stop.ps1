# vmware_stop_vm.ps1
# Универсальный скрипт выключения ВМ с автопоиском файла .vmx

# ================= НАСТРОЙКИ =================
$vmrunPath = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
$vmName = "demo305"
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

# 🔍 УМНЫЙ ПОИСК: ищем файл .vmx в стандартных местах
Write-Host "1. Поиск виртуальной машины '$vmName'..." -ForegroundColor Yellow
$possiblePaths = @(
    "C:\Users\Student\Desktop\shared\VM\$vmName\$vmName.vmx",
    "C:\Users\Student\Documents\Virtual Machines\$vmName\$vmName.vmx",
    "C:\Users\Student\Documents\$vmName\$vmName.vmx",
    "C:\VMs\$vmName\$vmName.vmx",
    "D:\VMs\$vmName\$vmName.vmx"
)

$vmxPath = $null
foreach ($p in $possiblePaths) {
    if (Test-Path $p) {
        $vmxPath = $p
        break
    }
}

# Если не нашли в стандартных местах — ищем по всему диску C:
if (-not $vmxPath) {
    Write-Host "   Не найдена в стандартных местах. Ищу на диске C:..." -ForegroundColor DarkGray
    $found = Get-ChildItem -Path "C:\" -Filter "$vmName.vmx" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $vmxPath = $found.FullName
    }
}

if (-not $vmxPath) {
    Write-Error "Виртуальная машина '$vmName' не найдена на этом компьютере!"
    exit 1
}

Write-Host "   ✅ Найдена: $vmxPath" -ForegroundColor Green

# 2. Проверяем, запущена ли ВМ
Write-Host "2. Проверка состояния ВМ..." -ForegroundColor Yellow
$runningVMs = & $vmrunPath list 2>&1
$vmRunning = $runningVMs | Where-Object { $_ -match [regex]::Escape($vmxPath) }

if (-not $vmRunning) {
    Write-Host "   ВМ уже выключена. Нечего делать." -ForegroundColor Green
    exit 0
}

Write-Host "   ВМ запущена. Пытаюсь выключить..." -ForegroundColor Yellow

# 3. Мягкое выключение (ACPI shutdown)
Write-Host "3. Мягкое выключение (soft)..." -ForegroundColor Yellow
& $vmrunPath stop $vmxPath soft 2>&1 | Out-Null

# 4. Ждём, пока ВМ реально остановится
Write-Host "4. Ожидание остановки (до $shutdownTimeoutSec сек)..." -ForegroundColor Yellow
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

# 5. Если не выключилась — принудительно
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