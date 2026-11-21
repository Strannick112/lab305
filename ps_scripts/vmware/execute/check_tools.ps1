# Конфигурация
. "$PSScriptRoot\..\config\config.ps1"
. $PSScriptRoot\..\..\Invoke-OnAll.ps1

Invoke-OnAll {
    # Ищем .vmx файл (как в вашем скрипте)
    $vmx = Get-ChildItem -Path "C:\" -Filter "demo305.vmx" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (-not $vmx) {
        Write-Host "❌ ВМ не найдена" -ForegroundColor Red
        return
    }
    
    # Проверяем VMware Tools
    $result = & $vmrunPath getGuestIPAddress $vmx.FullName 2>&1
    
    if ($result -match "^\d+\.\d+\.\d+\.\d+$") {
        Write-Host "✅ VMware Tools установлены. IP: $result" -ForegroundColor Green
    } else {
        Write-Host "❌ VMware Tools НЕ установлены или не работают" -ForegroundColor Red
        Write-Host "   Ответ: $result" -ForegroundColor DarkGray
    }
}