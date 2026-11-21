# Загружаем конфигурацию и функции
# cd ..\..
. $PSScriptRoot\..\..\Invoke-OnAll.ps1
. $PSScriptRoot\..\code\send_file.ps1

$result = Invoke-RemoteCopyFile -LocalPath $torrentFilePath -RemoteFolder $torrentRemoteFilePath
