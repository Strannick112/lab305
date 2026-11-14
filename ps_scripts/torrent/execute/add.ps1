Write-Host "`nПереход к добавлению торрента в клиент..." -ForegroundColor Magenta
# Шаг 2: Добавление торрента
$addSuccess = & "$PSScriptRoot\..\code\add.ps1"

if ($addSuccess) {
    Write-Host "`n🎉 ВСЕ ОПЕРАЦИИ ЗАВЕРШЕНЫ УСПЕШНО! 🎉" -ForegroundColor Green
} else {
    Write-Host "`n❌ Ошибка на этапе добавления торрента." -ForegroundColor Red
}

. $PSScriptRoot\..\..\Invoke-OnAll.ps1

Invoke-RemoteScriptFolder -LocalFolder "$PSScriptRoot\.." -ScriptName "code\add.ps1"-Cleanup