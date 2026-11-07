# add_torrent.ps1
# Подключаем конфигурацию из той же папки
. "$PSScriptRoot\..\config\config.ps1"

if (-Not (Test-Path $torrentFilePath)) {
    Write-Error "Файл торрента не найден: $torrentFilePath"
    return $false
}

Write-Host "1. Авторизация в qBittorrent..." -ForegroundColor Yellow
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$loginResponse = Invoke-WebRequest -Uri "$qbHost/api/v2/auth/login" -Method Post -Body @{ username = $qbUser; password = $qbPass } -WebSession $session

if ($loginResponse.Content -ne "Ok.") {
    Write-Error "Ошибка авторизации."
    return $false
}

Write-Host "2. Добавление торрента в очередь загрузок..." -ForegroundColor Yellow
$torrentBytes = [System.IO.File]::ReadAllBytes($torrentFilePath)
$boundary = [System.Guid]::NewGuid().ToString()
$LF = "`r`n"

$bodyLines = @(
    "--$boundary",
    "Content-Disposition: form-data; name=`"torrents`"; filename=`"$torrentName.torrent`"",
    "Content-Type: application/x-bittorrent",
    "",
    [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString($torrentBytes),
    "--$boundary",
    "Content-Disposition: form-data; name=`"savepath`"",
    "",
    $vmFolder,
    "--$boundary--"
) -join $LF

$headers = @{ "Content-Type" = "multipart/form-data; boundary=$boundary" }

try {
    $addResponse = Invoke-WebRequest -Uri "$qbHost/api/v2/torrents/add" -Method Post -Body $bodyLines -Headers $headers -WebSession $session
    $statusCode = $addResponse.StatusCode
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 409) {
        $statusCode = 409 # 409 означает "Торрент уже добавлен", что для нас успех
    } else {
        Write-Error "Ошибка при добавлении: $($_.Exception.Message)"
        return $false
    }
}

if ($statusCode -eq 200 -or $statusCode -eq 409) {
    Write-Host "`n✅ УСПЕХ! Торрент добавлен в qBittorrent." -ForegroundColor Green
    Write-Host "   Путь к файлу: $torrentFilePath" -ForegroundColor Cyan
    return $true
} else {
    Write-Error "Ошибка при добавлении торрента. Код: $statusCode"
    return $false
}
