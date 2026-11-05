$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$username = "admin"
$password = Get-Content "..\..\credentials\torrent_password.txt"
Invoke-WebRequest -Uri "http://localhost:8082/api/v2/auth/login" -Method Post -Body @{username=$username; password=$password} -WebSession $session | Out-Null

# ��������� ���������� endpoint
$response = Invoke-WebRequest -Uri "http://localhost:8082/api/v2/torrents/createTorrent" -Method Post -Body @{} -WebSession $session
Write-Host "Status: $($response.StatusCode)"
Write-Host "Response: $($response.Content)"
