$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$username = Get-Content "..\..\credentials\user.txt"
$password = Get-Content "..\..\credentials\torrent_password.txt"
$qbhost = Get-Content "..\..\credentials\host.txt"
Invoke-WebRequest -Uri "$qbhost/api/v2/auth/login" -Method Post -Body @{username=$username; password=$password} -WebSession $session | Out-Null

# ��������� ���������� endpoint
$response = Invoke-WebRequest -Uri "qbhost/api/v2/torrents/createTorrent" -Method Post -Body @{} -WebSession $session
Write-Host "Status: $($response.StatusCode)"
Write-Host "Response: $($response.Content)"
