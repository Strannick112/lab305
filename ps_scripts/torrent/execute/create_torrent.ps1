Write-Host "=== Запуск процесса резервного копирования ВМ через торрент ===" -ForegroundColor Magenta

$createSuccess = & "$PSScriptRoot\..\code\create_torrent.ps1"
