# create_torrent.ps1
# Подключаем конфигурацию из той же папки
. "$PSScriptRoot\..\config\config.ps1"


Write-Host "1. Авторизация в qBittorrent..." -ForegroundColor Yellow
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$loginResponse = Invoke-WebRequest -Uri "$qbHost/api/v2/auth/login" -Method Post -Body @{ username = $qbUser; password = $qbPass } -WebSession $session -UseBasicParsing

if ($loginResponse.Content -ne "Ok.") {
    Write-Error "Ошибка авторизации. Проверьте логин и пароль в config.ps1."
    return $false
}

Write-Host "2. Запуск задачи создания торрента..." -ForegroundColor Yellow
$taskBody = @{
    sourcePath        = $vmSimLinksFolder
    torrentFilePath   = $torrentFilePath
    format            = "hybrid"
    startSeeding      = "true"
    isPrivate         = "false"
    optimizeAlignment = "true"
    pieceSize         = 0
    comment           = "VM $torrentName backup"
    trackers          = $trackers
}

$taskResponse = Invoke-WebRequest -Uri "$qbHost/api/v2/torrentcreator/addTask" -Method Post -Body $taskBody -WebSession $session -UseBasicParsing
$taskData = $taskResponse.Content | ConvertFrom-Json
$taskId = $taskData.taskID
Write-Host "   Задача создана. ID: $taskId" -ForegroundColor Cyan

Write-Host "3. Ожидание создания торрента..." -ForegroundColor Yellow
$maxAttempts = 300
$attempt = 0
$status = "Queued"

while ($attempt -lt $maxAttempts) {
    Start-Sleep -Seconds 2
    $attempt++
    
    # Проверка появления файла на диске (самый надежный индикатор)
    if (Test-Path $torrentFilePath) {
        $fileInfo = Get-Item $torrentFilePath
        if ($fileInfo.Length -gt 0) {
            Write-Host "   Файл торрента успешно создан на диске!" -ForegroundColor Green
            $status = "Finished"
            break
        }
    }

    # Проверка через API
    $statusResponse = Invoke-WebRequest -Uri "$qbHost/api/v2/torrentcreator/status?taskID=$taskId" -Method Get -WebSession $session -UseBasicParsing
    $statusData = $statusResponse.Content | ConvertFrom-Json
    
    $currentStatus = if ($statusData.status) { $statusData.status } else { $statusData[0].status }
    if ($currentStatus) {
        $status = $currentStatus
        if ($status -eq "Finished") { break }
        if ($status -eq "Failed") { 
            Write-Warning "Задача создания торрента завершилась с ошибкой."
            break 
        }
    }
}

if ($status -ne "Finished") {
    Write-Warning "Превышено время ожидания или ошибка. Статус: $status"
    return $false
}

Write-Host "4. Очистка задачи на сервере..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri "$qbHost/api/v2/torrentcreator/deleteTask" -Method Post -Body "taskID=$taskId" -WebSession $session -UseBasicParsing -ErrorAction Stop | Out-Null 
} catch {
    # Игнорируем ошибки очистки, так как файл уже создан
}

return $true
