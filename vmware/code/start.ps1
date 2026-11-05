# vmware_start_vm.ps1
# Универсальный скрипт запуска ВМ с автопоиском файла .vmx

# ================= НАСТРОЙКИ =================
$vmrunPath = Get-Content "..\config\vm_path.txt"
$vmName = Get-Content "..\config\vm_name.txt"
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

$vmxPath = Get-Content "..\config\vmx_path.txt"

# 1. Проверяем, не запущена ли ВМ уже
Write-Host "1. Проверка состояния ВМ..." -ForegroundColor Yellow
$runningVMs = & $vmrunPath list 2>&1
$vmRunning = $runningVMs | Where-Object { $_ -match [regex]::Escape($vmxPath) }

if ($vmRunning) {
    Write-Host "   ВМ уже запущена. Нечего делать." -ForegroundColor Green
    exit 0
}

# 2. Запускаем ВМ
Write-Host "2. Запуск ВМ в режиме '$startMode'..." -ForegroundColor Yellow
& $vmrunPath start $vmxPath $startMode 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Error "Команда запуска вернула код ошибки: $LASTEXITCODE"
    exit 1
}

# 3. Ждём, пока ВМ реально появится в списке запущенных
Write-Host "3. Ожидание запуска (до $startupTimeoutSec сек)..." -ForegroundColor Yellow
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

# 4. Опционально: ждём получения IP-адреса (требует VMware Tools)
if ($waitForIP) {
    Write-Host "4. Ожидание получения IP-адреса (до $ipTimeoutSec сек)..." -ForegroundColor Yellow
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