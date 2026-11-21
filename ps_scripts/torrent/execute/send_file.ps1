# Загружаем конфигурацию и функции
# cd ..\..
. $PSScriptRoot\..\..\Invoke-OnAll.ps1
. $PSScriptRoot\..\code\send_file.ps1

# Копируем торрент-файл на все компьютеры в папку Downloads
$torrentFilePath = Get-Content "$PSScriptRoot\..\config\torrent_file_path.txt"
$torrentRemoteFilePath = Get-Content "$PSScriptRoot\..\config\torrent_remote_file_path.txt"

$result = Invoke-RemoteCopyFile -LocalPath $torrentFilePath -RemoteFolder $torrentRemoteFilePath
