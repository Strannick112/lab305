Write-Host "=== Запуск процесса резервного копирования ВМ через торрент ===" -ForegroundColor Magenta

$createSuccess = & "$PSScriptRoot\..\code\create_torrent.ps1"

if ($createSuccess) {
    Write-Host "`n🎉 ВСЕ ОПЕРАЦИИ ЗАВЕРШЕНЫ УСПЕШНО! 🎉" -ForegroundColor Green
} else {
    Write-Host "`n❌ Ошибка на этапе создания торрента." -ForegroundColor Red
}
