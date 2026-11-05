# Путь к vmrun (используйте полный путь, если vmrun не в PATH)
$vmrunPath = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
$vmxPath = "C:\Users\Student\Documents\Virtual Machines\demo305\demo305.vmx"

# Получаем список всех снапшотов
$snapshots = & $vmrunPath -T ws listSnapshots $vmxPath

# Выводим список для проверки
Write-Host "Найденные снапшоты:" -ForegroundColor Cyan
Write-Host $snapshots

# Извлекаем имена снапшотов (пропускаем первую строку с общим количеством)
$snapshotNames = $snapshots -split "`n" | Select-Object -Skip 1 | Where-Object { $_ -ne "" }

if ($snapshotNames.Count -eq 0) {
    Write-Error "Снапшоты не найдены!"
    exit
}

# Берем последний снапшот (предполагаем, что он самый свежий)
$latestSnapshot = $snapshotNames[-1].Trim()

Write-Host "Откатываем к самому свежему снапшоту: $latestSnapshot" -ForegroundColor Yellow

# Выполняем откат
& $vmrunPath -T ws revertToSnapshot $vmxPath $latestSnapshot

Write-Host "Откат завершен!" -ForegroundColor Green