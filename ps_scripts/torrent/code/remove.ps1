# remove.ps1
# Удаляет торрент из очереди загрузок qBittorrent
# ВАЖНО: Сохраните в UTF-8 with BOM

# ================= НАСТРОЙКИ =================

# Удалять ли файлы с диска вместе с торрентом?
# $false — удалить только из списка загрузок (файлы останутся)
# $true  — удалить и торрент, и скачанные файлы с диска
. "$PSScriptRoot\..\config\config.ps1"

# Проверка, запущен ли qbittorrent
. "$PSScriptRoot\check_online.ps1"

# Авторизация в qbittorrent
. "$PSScriptRoot\auth.ps1"

$deleteFiles = $false
$deleteFilesStr = if ($deleteFiles) { "true" } else { "false" }
# =============================================

Write-Host "=== Удаление торрента '$torrentName' на $env:COMPUTERNAME ===" -ForegroundColor Cyan

# 2. Ищем торрент по имени
Write-Host "2. Поиск торрента '$torrentName'..." -ForegroundColor Yellow

try {
    $torrents = Invoke-WebRequest -Uri "$qbHost/api/v2/torrents/info" -WebSession $session -UseBasicParsing | ConvertFrom-Json
} catch {
    Write-Error "Не удалось получить список торрентов: $_"
    exit 1
}

if ($torrents.Count -eq 0) {
    Write-Host "   ℹ️  Список загрузок пуст." -ForegroundColor Yellow
    exit 0
}

Write-Host "   Найдено торрентов: $($torrents.Count)" -ForegroundColor Yellow

$allHashes = ($torrents | ForEach-Object { $_.hash }) -join "|"

# 3. Удаляем торрент
Write-Host "4. Очистка списка торрентов..." -ForegroundColor Yellow

try {
    $deleteResponse = Invoke-WebRequest -Uri "$qbHost/api/v2/torrents/delete" -Method Post -Body @{
        hashes = $allHashes
        deleteFiles = $deleteFilesStr
    } -WebSession $session -UseBasicParsing
    if ($deleteResponse.StatusCode -eq 200) {
        Write-Host "`n✅ Список торрентов в qBittorrent успешно очищен." -ForegroundColor Green
        if ($deleteFiles) {
            Write-Host "   ⚠️  Файлы с диска ТАКЖЕ УДАЛЕНЫ!" -ForegroundColor Red
        } else {
            Write-Host "   ℹ️  Файлы на диске сохранены." -ForegroundColor Cyan
        }
        exit 0
    } else {
        Write-Error "qBittorrent вернул код: $($deleteResponse.StatusCode)"
        exit 1
    }
} catch {
    Write-Error "Ошибка при удалении торрента: $_"
    exit 1
}

exit 0
