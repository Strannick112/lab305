# List-Computers.ps1 — диагностика и список компьютеров

# Принудительно выводим всё в консоль
$Host.UI.RawUI.WindowTitle = "Список компьютеров"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Запуск скрипта..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    # 1. Проверяем наличие файлов
    $credPath = "C:\Scripts\"
    $userFile = "$credPath\username.txt"
    $passFile = "$credPath\password.txt"
    $compFile = "$credPath\computers.txt"

    if (-not (Test-Path $userFile)) { throw "Не найден файл: $userFile" }
    if (-not (Test-Path $passFile)) { throw "Не найден файл: $passFile" }
    if (-not (Test-Path $compFile)) { throw "Не найден файл: $compFile" }

    Write-Host "✅ Все файлы найдены" -ForegroundColor Green

    # 2. Загружаем данные
    $user = (Get-Content $userFile).Trim()
    $pass = (Get-Content $passFile).Trim() | ConvertTo-SecureString
    $cred = New-Object System.Management.Automation.PSCredential($user, $pass)
    $computers = Get-Content $compFile | Where-Object { $_.Trim() -ne "" }

    Write-Host "✅ Учётные данные загружены. Компьютеров в списке: $($computers.Count)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Опрос компьютеров..." -ForegroundColor Yellow
    Write-Host ""

    # 3. Опрос
    $online = 0
    $offline = 0

    foreach ($pc in $computers) {
        try {
            $name = Invoke-Command -ComputerName $pc -Credential $cred -ScriptBlock { $env:COMPUTERNAME } -ErrorAction Stop
            Write-Host "  ✅ $pc  ->  $name" -ForegroundColor Green
            $online++
        }
        catch {
            Write-Host "  ❌ $pc  ->  Недоступен" -ForegroundColor Red
            $offline++
        }
    }

    # 4. Итог
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " ИТОГО: Включено: $online | Недоступно: $offline" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}
catch {
    Write-Host ""
    Write-Host "!!! ОШИБКА !!!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
}

# Пауза в самом конце — ОБЯЗАТЕЛЬНО
Write-Host ""
Read-Host "Нажмите Enter для выхода"