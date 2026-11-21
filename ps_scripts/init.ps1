# Создаём папку credentials, если её нет
$credFolder = Join-Path $PSScriptRoot "credentials"
New-Item -ItemType Directory -Path $credFolder -Force | Out-Null

# Запрашиваем учётные данные
$cred = Get-Credential -Message "Введите логин и пароль локального администратора"

# Сохраняем логин
$cred.UserName | Set-Content -LiteralPath (Join-Path $credFolder "username.txt") -Encoding UTF8

# Сохраняем пароль (зашифрованным через DPAPI)
$cred.Password | ConvertFrom-SecureString | Set-Content -LiteralPath (Join-Path $credFolder "password.txt") -Encoding UTF8

Write-Host "✅ Учётные данные сохранены" -ForegroundColor Green
Write-Host "   Логин: $($cred.UserName)" -ForegroundColor Cyan