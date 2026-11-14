# Загружаем конфигурацию
. $PSScriptRoot\..\..\Invoke-OnAll.ps1

# Запускаем на всех машинах параллельно
Invoke-RemoteScriptFolder -LocalFolder "$PSScriptRoot\.." -ScriptName "start.ps1" -Cleanup