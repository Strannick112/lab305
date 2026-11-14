. $PSScriptRoot\..\..\Invoke-OnAll.ps1

# Invoke-RemoteScriptFolder -LocalFolder "C:\Scripts" -ScriptName "vmware_snapshot_callback.ps1" -Cleanup
Invoke-RemoteScriptFolder -LocalFolder "$PSScriptRoot\.." -ScriptName "\code\snapshot_clean.ps1" -Cleanup