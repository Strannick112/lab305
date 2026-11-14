# Запуск от имени администратора (обязательно для симлинков!)
$createSimLinksSuccess = & "$PSScriptRoot\..\code\create_simlinks.ps1"

if ($createSimLinksSuccess) {
    Write-Host "`n🎉 ВСЕ ОПЕРАЦИИ ЗАВЕРШЕНЫ УСПЕШНО! 🎉" -ForegroundColor Green
} else {
    Write-Host "`n❌ Ошибка на этапе создания торрента." -ForegroundColor Red
}
