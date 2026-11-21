. $PSScriptRoot\..\..\Invoke-OnAll.ps1

# Invoke-RemoteScriptFolder -LocalFolder "C:\Scripts" -ScriptName "vmware_snapshot_callback.ps1" -Cleanup
$result = Invoke-RemoteScriptFolder -LocalFolder "$PSScriptRoot\.." -ScriptName "\code\clean.ps1" -Cleanup
