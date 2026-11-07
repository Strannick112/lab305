# Загружаем конфигурацию
. .\Invoke-OnAll.ps1

# Запускаем на всех машинах параллельно
Invoke-RemoteScriptFolder -LocalFolder "..\.." -ScriptName "vmware_start_vm.ps1" -Cleanup