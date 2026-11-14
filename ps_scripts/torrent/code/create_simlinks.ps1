# create_vm_torrent_symlinks.ps1
# Создаёт торрент через символические ссылки (без копирования файлов ВМ)

# ================= НАСТРОЙКИ =================
. "$PSScriptRoot\..\config\config.ps1"


# 0. Проверка прав администратора
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "⚠️  Скрипт запущен без прав администратора. Создание симлинков может не сработать."
    Write-Warning "   Запустите PowerShell от имени администратора или включите 'Режим разработчика' в Windows."
}

# 2. Фильтруем важные файлы
Write-Host "`nПоиск важных файлов..." -ForegroundColor Yellow

# Полный набор расширений, БЕЗ которых снапшот не работает:
#   .vmsd  — база данных снапшотов (без неё снапшоты НЕВИДИМЫ!)
#   .vmsn  — состояние памяти снапшота
#   .vmx1  — конфиг снапшота
#   .vmdk  — базовый диск + дельты
#   .vmss  — suspend-состояние
#   .nvram — BIOS/UEFI
#   .vmx / .vmxf — конфиг ВМ
#   .iso   — образ CD (опционально, но лучше включить)
$importantExtensions = @('.vmdk', '.vmsd', '.vmsn', '.vmx', '.vmx1', '.vmxf', '.vmss', '.nvram', '.iso')
# =============================================

$importantFiles = Get-ChildItem -Path $vmFolder -File | Where-Object {
    $_.Extension -in $importantExtensions -and
    $_.Name -notmatch '\.lck$' -and
    $_.Name -notmatch '^vmware-' -and
    $_.Name -notmatch '\.tmp$' -and
    $_.Name -notmatch '\.dmp$'
}

if ($importantFiles.Count -eq 0) {
    Write-Error "Важные файлы не найдены!"
    exit 1
}

$importantFiles = $importantFiles | Sort-Object Name

$totalSize = ($importantFiles | Measure-Object -Property Length -Sum).Sum
$totalGB = [math]::Round($totalSize / 1GB, 2)
Write-Host "Найдено $($importantFiles.Count) файлов, общий размер: $totalGB ГБ" -ForegroundColor Green

# 3. Создаём папку для симлинков
if (Test-Path $vmSimLinksFolder) {
    Write-Host "Очищаем старую папку симлинков: $vmSimLinksFolder" -ForegroundColor DarkGray
    Remove-Item -Path $vmSimLinksFolder -Recurse -Force
}
New-Item -ItemType Directory -Path $vmSimLinksFolder -Force | Out-Null

# 4. Создаём символические ссылки
Write-Host "`nСоздание символических ссылок..." -ForegroundColor Yellow
$createdLinks = 0
$failedLinks = 0

foreach ($file in $importantFiles) {
    $linkPath = Join-Path $vmSimLinksFolder $file.Name
    
    try {
        # Создаём симлинк на файл
        New-Item -ItemType SymbolicLink -Path $linkPath -Target $file.FullName -Force | Out-Null
        
        # Проверяем, что ссылка создана корректно
        if (Test-Path $linkPath) {
            $sizeMB = [math]::Round($file.Length / 1MB, 2)
            Write-Host "  ✅ $($file.Name) -> $($file.FullName) ($sizeMB МБ)" -ForegroundColor DarkGray
            $createdLinks++
        } else {
            Write-Warning "  ❌ $($file.Name): ссылка создана, но недоступна"
            $failedLinks++
        }
    }
    catch {
        Write-Warning "  ❌ $($file.Name): $($_.Exception.Message)"
        $failedLinks++
        
        # Fallback: пробуем hardlink (работает только на одном диске)
        try {
            New-Item -ItemType HardLink -Path $linkPath -Target $file.FullName -Force | Out-Null
            Write-Host "  🔗 $($file.Name): создан hardlink вместо symlink" -ForegroundColor Yellow
            $createdLinks++
        }
        catch {
            Write-Error "  ❌ $($file.Name): не удалось создать ни symlink, ни hardlink"
        }
    }
}

Write-Host "`nСоздано ссылок: $createdLinks, ошибок: $failedLinks" -ForegroundColor $(if ($failedLinks -eq 0) { "Green" } else { "Yellow" })

if ($createdLinks -eq 0) {
    Write-Error "Не удалось создать ни одной ссылки. Проверьте права администратора."
    exit 1
}

# 5. Итоговая информация
Write-Host "`n===================================================" -ForegroundColor Cyan
Write-Host "ИТОГ" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "Симлинки: $vmSimLinksFolder" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  ВАЖНО: Не удаляйте папку $vmSimLinksFolder" -ForegroundColor Yellow
Write-Host "   Пока торрент раздаётся, qBittorrent читает файлы через эти ссылки."
Write-Host "   Удаление симлинков = потеря сида."
Write-Host ""
Write-Host "Для очистки после завершения раздачи:" -ForegroundColor DarkGray
Write-Host "   Remove-Item -Path '$vmSimLinksFolder' -Recurse -Force" -ForegroundColor DarkGray

return $true
