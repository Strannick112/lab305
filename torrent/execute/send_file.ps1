# Загружаем конфигурацию и функции
. .\Invoke-OnAll.ps1

# Копируем торрент-файл на все компьютеры в папку Downloads
$torrentFilePath = Get-Content "..\config\torrent_file_path.txt"
$torrentFilePath = Get-Content "..\config\torrent_remote_file_path.txt"

Invoke-RemoteCopyFile -LocalPath $torrentFilePath -RemoteFolder $torrentFilePath