. $PSScriptRoot\..\..\Invoke-OnAll.ps1

# предпросмотр на всех машинах
Invoke-RemoteScriptFolder -LocalFolder "$PSScriptRoot\.." -ScriptName 'code\clean_desktop.ps1' -Arguments @{ WhatIf = $false } -Cleanup

# боевой запуск
# Invoke-RemoteScriptFolder -LocalFolder 'C:\Admin\clean_scripts' -ScriptName 'Clean-Desktop.ps1'   -Cleanup
