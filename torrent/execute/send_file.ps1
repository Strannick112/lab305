# Загружаем конфигурацию
. .\Invoke-OnAll.ps1

# Копируем торрент-файл на все компьютеры в папку Downloads
Invoke-RemoteCopyFile -LocalPath "C:\Users\Student\Desktop\shared\VM\demo305.torrent" -RemoteFolder "C:\Users\Student\Downloads"