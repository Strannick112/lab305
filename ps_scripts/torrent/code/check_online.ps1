# 0. Проверяем, запущен ли qBittorrent
Write-Host "0. Проверка состояния qBittorrent..." -ForegroundColor Yellow
$qbProcess = Get-Process qbittorrent -ErrorAction SilentlyContinue

if (-not $qbProcess) {
    Write-Warning "qBittorrent не запущен. Пытаюсь запустить..."
    try {
        Start-Process "qbittorrent.exe" -WindowStyle Hidden -ErrorAction Stop
        Start-Sleep -Seconds 5 # Ждем инициализации Web UI
    } catch {
        Write-Error "Не удалось запустить qBittorrent. Убедитесь, что он установлен."
        exit 1
    }
} else {
    Write-Host "   ✅ qBittorrent уже запущен" -ForegroundColor Green
}
