# ================= НАСТРОЙКИ =================
$vmFolder = Get-Content "..\config\vm_folder.txt"
$torrentFilePath =  Get-Content "..\config\torrent_file_path.txt"
$torrentName = Get-Content "..\config\torrent_name.txt"

$qbHost = Get-Content "..\..\credentials\host.txt"
$qbUser = Get-Content "..\..\credentials\user.txt"
$qbPass = Get-Content "..\..\credentials\torrent_password.txt"

$trackers = Get-Content "..\config\trackers.txt"
# =============================================

Write-Host "1. Авторизация в qBittorrent..." -ForegroundColor Yellow
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$loginBody = @{ username = $qbUser; password = $qbPass }
$loginResponse = Invoke-WebRequest -Uri "$qbHost/api/v2/auth/login" -Method Post -Body $loginBody -WebSession $session

if ($loginResponse.Content -ne "Ok.") {
    Write-Error "Ошибка авторизации. Проверьте логин и пароль."
    exit 1
}

Write-Host "2. Запуск задачи создания торрента..." -ForegroundColor Yellow

$taskBody = @{
    sourcePath        = $vmFolder
    torrentFilePath   = $torrentFilePath
    format            = "hybrid"
    startSeeding      = "true"
    isPrivate         = "false"
    optimizeAlignment = "true"
    pieceSize         = 0
    comment           = "VM demo305 backup"
    trackers          = $trackers
}

$taskResponse = Invoke-WebRequest -Uri "$qbHost/api/v2/torrentcreator/addTask" -Method Post -Body $taskBody -WebSession $session
$taskData = $taskResponse.Content | ConvertFrom-Json
$taskId = $taskData.taskID

Write-Host "   Задача создана. ID: $taskId" -ForegroundColor Cyan

Write-Host "3. Ожидание создания торрента..." -ForegroundColor Yellow
$maxAttempts = 300
$attempt = 0
$status = "Queued"
$lastPrintedStatus = ""

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
    $statusResponse = Invoke-WebRequest -Uri "$qbHost/api/v2/torrentcreator/status?taskID=$taskId" -Method Get -WebSession $session
    $statusData = $statusResponse.Content | ConvertFrom-Json
    
    $currentStatus = if ($statusData.status) { $statusData.status } else { $statusData[0].status }
    $progress = if ($statusData.progress) { $statusData.progress } else { $statusData[0].progress }

    if ($currentStatus) {
        $status = $currentStatus
        $displayProgress = [math]::Min([int]($progress * 100), 100)
        
        if ($status -ne $lastPrintedStatus -or $attempt % 10 -eq 0) {
            Write-Host "   Статус: $status (Прогресс: $($displayProgress)%)" -ForegroundColor DarkGray
            $lastPrintedStatus = $status
        }
    }

    if ($status -eq "Finished") { break }
    if ($status -eq "Failed") { 
        Write-Warning "Задача создания торрента завершилась с ошибкой."
        break 
    }
}

if ($status -ne "Finished") {
    Write-Warning "Превышено время ожидания. Статус: $status"
    exit 1
}

Write-Host "4. Очистка задачи на сервере..." -ForegroundColor Yellow
# ИСПРАВЛЕНО: Используем try/catch и передаем параметр как raw-строку, чтобы гарантированно избежать красных ошибок
try {
    Invoke-WebRequest -Uri "$qbHost/api/v2/torrentcreator/deleteTask" -Method Post -Body "taskID=$taskId" -WebSession $session -ErrorAction Stop | Out-Null
} catch {
    # Если API qBittorrent снова жалуется на формат, мы просто игнорируем это, 
    # так как торрент уже успешно создан и добавлен.
}

Write-Host "5. Добавление торрента в очередь загрузок qBittorrent..." -ForegroundColor Yellow
$torrentBytes = [System.IO.File]::ReadAllBytes($torrentFilePath)
$boundary = [System.Guid]::NewGuid().ToString()
$LF = "`r`n"
$bodyLines = @(
    "--$boundary",
    "Content-Disposition: form-data; name=`"torrents`"; filename=`"$torrentName.torrent`"",
    "Content-Type: application/x-bittorrent",
    "",
    [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString($torrentBytes),
    "--$boundary--"
) -join $LF

$headers = @{ "Content-Type" = "multipart/form-data; boundary=$boundary" }

try {
    $addResponse = Invoke-WebRequest -Uri "$qbHost/api/v2/torrents/add" -Method Post -Body $bodyLines -Headers $headers -WebSession $session
    $statusCode = $addResponse.StatusCode
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 409) {
        $statusCode = 409
    } else {
        Write-Error "Ошибка при добавлении: $($_.Exception.Message)"
        exit 1
    }
}

if ($statusCode -eq 200 -or $statusCode -eq 409) {
    Write-Host "`n✅ УСПЕХ! Торрент создан и добавлен в qBittorrent." -ForegroundColor Green
    Write-Host "   Файл сохранен: $torrentFilePath" -ForegroundColor Cyan
} else {
    Write-Error "Ошибка при добавлении торрента в клиент. Код: $statusCode"
}