# check_disk_space.ps1
# Проверяет дисковое пространство на удалённой машине


# Устанавливаем правильную кодировку для вывода
# [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# $OutputEncoding = [System.Text.Encoding]::UTF8

$warningThreshold = 20  # Предупреждение, если свободно меньше 20%
$criticalThreshold = 10 # Критично, если свободно меньше 10%

Write-Host "=== Дисковое пространство на $env:COMPUTERNAME ===" -ForegroundColor Cyan

$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Sort-Object DeviceID

if (-not $disks) {
    Write-Host "   Фиксированные диски не найдены" -ForegroundColor Yellow
    exit 0
}

foreach ($disk in $disks) {
    $sizeGB = [math]::Round($disk.Size / 1GB, 2)
    $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    $usedGB = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
    $usedPercent = [math]::Round(($disk.Size - $disk.FreeSpace) / $disk.Size * 100, 1)
    $freePercent = [math]::Round($disk.FreeSpace / $disk.Size * 100, 1)
    
    # Определяем цвет по проценту свободного места
    if ($freePercent -le $criticalThreshold) {
        $color = "Red"
        $icon = "🔴"
    } elseif ($freePercent -le $warningThreshold) {
        $color = "Yellow"
        $icon = "🟡"
    } else {
        $color = "Green"
        $icon = "🟢"
    }
    
    Write-Host "`n$icon Диск $($disk.DeviceID) ($($disk.VolumeName))" -ForegroundColor $color
    Write-Host "   Размер   : $sizeGB ГБ" -ForegroundColor DarkGray
    Write-Host "   Занято   : $usedGB ГБ ($usedPercent%)" -ForegroundColor DarkGray
    Write-Host "   Свободно : $freeGB ГБ ($freePercent%)" -ForegroundColor DarkGray
    
    # Визуальная шкала заполнения
    $barLength = 30
    $filled = [math]::Round($usedPercent / 100 * $barLength)
    $empty = $barLength - $filled
    $bar = ("#" * $filled) + ("." * $empty)
    Write-Host "   [$bar] $usedPercent%" -ForegroundColor $color
}

# Итоговая сводка
$lowDisk = $disks | Where-Object { 
    [math]::Round($_.FreeSpace / $_.Size * 100, 1) -le $warningThreshold 
}

if ($lowDisk) {
    Write-Host "`n⚠️  ВНИМАНИЕ: На дисках мало свободного места:" -ForegroundColor Yellow
    $lowDisk | ForEach-Object {
        $freePct = [math]::Round($_.FreeSpace / $_.Size * 100, 1)
        Write-Host "   - $($_.DeviceID): свободно $freePct%" -ForegroundColor Yellow
    }
}