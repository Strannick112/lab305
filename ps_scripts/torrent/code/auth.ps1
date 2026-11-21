# 1. Авторизация

Write-Host "1. Авторизация в qBittorrent..." -ForegroundColor Yellow

try {
    $loginResponse = Invoke-WebRequest -Uri "$qbHost/api/v2/auth/login" -Method Post -Body @{
        username = $qbUser; password = $qbPass
    } -WebSession $session -UseBasicParsing -TimeoutSec 10
    
    if ($loginResponse.Content -ne "Ok.") {
        Write-Error "Ошибка авторизации. Проверьте логин и пароль."
        exit 1
    }
    Write-Host "   ✅ Успешно" -ForegroundColor Green
} catch {
    Write-Error "Не удалось подключиться к qBittorrent: $_"
    exit 1
}
