# ================= НАСТРОЙКИ =================
$vmxPath = Get-Content "..\config\vmx_path.txt"

# Автоматический поиск vmrun.exe
$vmrunPath = Get-Content "..\config\vm_path.txt"
if (-Not (Test-Path $vmrunPath)) {
    $vmrunPath = Get-Content "..\config\vm_x64_path.txt"
}

if (-Not (Test-Path $vmrunPath)) {
    Write-Error "Не удалось найти vmrun.exe. Проверьте установку VMware Workstation."
    exit 1
}
# =============================================

Write-Host "1. Получение списка снапшотов..." -ForegroundColor Yellow
$rawOutput = & $vmrunPath -T ws listSnapshots $vmxPath

# Парсинг вывода: пропускаем первую строку ("Total snapshots: N") и пустые строки
$snapshots = $rawOutput -split "`n" | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }

if ($snapshots.Count -eq 0) {
    Write-Host "Снапшоты не найдены. Нечего удалять." -ForegroundColor Green
    exit 0
}

if ($snapshots.Count -eq 1) {
    Write-Host "Найден только один снапшот ('$($snapshots[0])'). Он будет сохранен как самый свежий." -ForegroundColor Green
    exit 0
}

# В списке vmrun снапшоты идут в хронологическом порядке. Последний = самый свежий.
$latestSnapshot = $snapshots[-1]
Write-Host "Самый свежий снапшот (БУДЕТ СОХРАНЕН): '$latestSnapshot'" -ForegroundColor Cyan
Write-Host "Найдено старых снапшотов для удаления: $($snapshots.Count - 1)" -ForegroundColor Yellow

Write-Host "`n2. Удаление старых снапшотов..." -ForegroundColor Yellow
$deletedCount = 0

foreach ($snapshot in $snapshots) {
    if ($snapshot -ne $latestSnapshot) {
        Write-Host "  Удаление: '$snapshot'..." -NoNewline
        
        # Выполняем удаление
        & $vmrunPath -T ws deleteSnapshot $vmxPath $snapshot 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host " [OK]" -ForegroundColor Green
            $deletedCount++
        } else {
            Write-Host " [ОШИБКА]" -ForegroundColor Red
        }
    }
}

Write-Host "`n✅ Готово! Удалено снапшотов: $deletedCount" -ForegroundColor Green
Write-Host "   Оставлен только: '$latestSnapshot'" -ForegroundColor Cyan