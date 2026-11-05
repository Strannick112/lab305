# vmware_start_vm.ps1
# Универсальный скрипт запуска ВМ с автопоиском файла .vmx

# ================= НАСТРОЙКИ =================
$vmrunPath = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
$vmName = "demo305"
$startMode = "gui"              # "gui" (с окном) или "nogui" (в фоне)
$startupTimeoutSec = 180        # Сколько ждать запуска ВМ
$checkIntervalSec = 5           # Интервал проверки статуса
$waitForIP = $true              # Ждать получения IP-адреса гостевой ОС
$ipTimeoutSec = 120             # Таймаут ожидания IP
# =============================================

Write-Host "=== Запуск ВМ на $env:COMPUTERNAME ===" -ForegroundColor Cyan

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

# 2. Проверяем, не запущена ли ВМ уже
Write-Host "2. Проверка состояния ВМ..." -ForegroundColor Yellow
$runningVMs = & $vmrunPath list 2>&1
$vmRunning = $runningVMs | Where-Object { $_ -match [regex]::Escape($vmxPath) }

if ($vmRunning) {
    Write-Host "   ВМ уже запущена. Нечего делать." -ForegroundColor Green
    exit 0
}

# 3. Запускаем ВМ
Write-Host "3. Запуск ВМ в режиме '$startMode'..." -ForegroundColor Yellow
& $vmrunPath start $vmxPath $startMode 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Error "Команда запуска вернула код ошибки: $LASTEXITCODE"
    exit 1
}

# 4. Ждём, пока ВМ реально появится в списке запущенных
Write-Host "4. Ожидание запуска (до $startupTimeoutSec сек)..." -ForegroundColor Yellow
$elapsed = 0
$started = $false

while ($elapsed -lt $startupTimeoutSec) {
    Start-Sleep -Seconds $checkIntervalSec
    $elapsed += $checkIntervalSec
    
    $runningVMs = & $vmrunPath list 2>&1
    $vmRunning = $runningVMs | Where-Object { $_ -match [regex]::Escape($vmxPath) }
    
    if ($vmRunning) {
        $started = $true
        break
    }
    
    Write-Host "   ... прошло $elapsed сек, ВМ ещё не запущена" -ForegroundColor DarkGray
}

if (-not $started) {
    Write-Error "ВМ не запустилась за $startupTimeoutSec сек!"
    exit 1
}

Write-Host "   ✅ ВМ запущена за $elapsed сек." -ForegroundColor Green

# 5. Опционально: ждём получения IP-адреса (требует VMware Tools)
if ($waitForIP) {
    Write-Host "5. Ожидание получения IP-адреса (до $ipTimeoutSec сек)..." -ForegroundColor Yellow
    $elapsed = 0
    $ipObtained = $false
    
    while ($elapsed -lt $ipTimeoutSec) {
        Start-Sleep -Seconds $checkIntervalSec
        $elapsed += $checkIntervalSec
        
        $ip = & $vmrunPath getGuestIPAddress $vmxPath -wait 2>&1
        
        if ($ip -and $ip -ne "Error: Unable to get the IP address" -and $ip -notmatch "Error") {
            $ipObtained = $true
            Write-Host "   ✅ IP-адрес получен: $ip" -ForegroundColor Green
            break
        }
        
        Write-Host "   ... прошло $elapsed сек, IP ещё не получен" -ForegroundColor DarkGray
    }
    
    if (-not $ipObtained) {
        Write-Warning "IP-адрес не получен за $ipTimeoutSec сек. Возможно, VMware Tools не установлены или гостевая ОС ещё загружается."
    }
}

Write-Host "`n✅ ВМ '$vmName' успешно запущена на $env:COMPUTERNAME." -ForegroundColor Green