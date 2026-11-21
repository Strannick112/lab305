. $PSScriptRoot\..\..\Invoke-OnAll.ps1

$result = Invoke-RemoteScriptFolder -LocalFolder "$PSScriptRoot\.." -ScriptName "code\get_memory.ps1" -Cleanup
