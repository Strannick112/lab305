# Загружаем конфигурацию
. .\Invoke-OnAll.ps1

# Запускаем на всех 20 машинах параллельно
Invoke-RemoteScriptFolder -LocalFolder "C:\Scripts" -ScriptName "vmware_stop_vm.ps1" -Cleanup