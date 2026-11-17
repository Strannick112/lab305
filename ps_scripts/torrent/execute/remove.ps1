# Загружаем инфраструктуру
. .\Invoke-OnAll.ps1

# Запускаем удаление на всех машинах параллельно
$result = Invoke-RemoteScriptFolder -LocalFolder "$PSScriptRoot\.." -ScriptName "code\remove.ps1" -Cleanup

# $removeSuccess = & "$PSScriptRoot\..\code\remove.ps1"

if ($removeSuccess) {
    Write-Host "`n🎉 ВСЕ ОПЕРАЦИИ ЗАВЕРШЕНЫ УСПЕШНО! 🎉" -ForegroundColor Green
} else {
    Write-Host "`n❌ Ошибка на этапе удаления торрента." -ForegroundColor Red
}
