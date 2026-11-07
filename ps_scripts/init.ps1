# Скрипт для инициализации учётных данных для удалённого администрирования

# Создаём папку credentials, если её нет
New-Item -ItemType Directory -Path ".\credentials" -Force | Out-Null

# Запрашиваем учётные данные через стандартный диалог Windows
$cred = Get-Credential -Message "Введите учётные данные для удалённого администрирования"

# Сохраняем логин (обычным текстом)
$cred.UserName | Set-Content -Path ".\credentials\username.txt" -Encoding UTF8

# Сохраняем пароль в виде Secure String (зашифрованным)
$cred.Password | ConvertFrom-SecureString | Set-Content -Path ".\credentials\password.txt" -Encoding UTF8

Write-Host "✅ Учётные данные успешно сохранены в папку .\credentials\" -ForegroundColor Green
Write-Host "   - username.txt: $($cred.UserName)" -ForegroundColor Cyan
Write-Host "   - password.txt: [зашифрован]" -ForegroundColor Cyan