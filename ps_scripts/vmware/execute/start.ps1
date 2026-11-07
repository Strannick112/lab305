# Загружаем конфигурацию
. $PSScriptRoot\..\..\Invoke-OnAll.ps1

# Запускаем на всех машинах параллельно
Invoke-RemoteScriptFolder -LocalFolder "$PSScriptRoot\..\.." -ScriptName "vmware_start_vm.ps1" -Cleanup