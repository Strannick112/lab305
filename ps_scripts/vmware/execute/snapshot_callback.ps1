# Копируем всю папку scripts\ и запускаем main.ps1 на всех машинах
. C:\Scripts\Invoke-OnAll.ps1

# Invoke-RemoteScriptFolder -LocalFolder "C:\Scripts" -ScriptName "vmware_snapshot_callback.ps1" -Cleanup
Invoke-RemoteScriptFolder -LocalFolder "C:\Scripts" -ScriptName "vmware_snapshot_clean.ps1" -Cleanup