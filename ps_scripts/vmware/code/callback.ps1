# Конфигурация
. "$PSScriptRoot\..\config\config.ps1"

# Захват вывода сразу в массив
$snapshots = @(& $vmrunPath -T ws listSnapshots $vmxPath)

if ($LASTEXITCODE -ne 0) {
    Write-Error "vmrun listSnapshots завершился с кодом $LASTEXITCODE"
    exit 1
}

Write-Host "Найденные снапшоты:" -ForegroundColor Cyan
$snapshots | ForEach-Object { Write-Host "  $_" }

# Пропускаем строку "Total snapshots: N", убираем пустые и пробелы
$snapshotNames = @(
    $snapshots |
        Select-Object -Skip 1 |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" }
)

if ($snapshotNames.Count -eq 0) {
    Write-Error "Снапшоты не найдены!"
    exit 1
}

$latestSnapshot = $snapshotNames[-1]
Write-Host "Откатываем к снапшоту: '$latestSnapshot'" -ForegroundColor Yellow

& $vmrunPath -T ws revertToSnapshot $vmxPath $latestSnapshot

if ($LASTEXITCODE -ne 0) {
    Write-Error "Откат не удался (код $LASTEXITCODE)"
    exit 1
}

Write-Host "Откат завершен!" -ForegroundColor Green
exit 0