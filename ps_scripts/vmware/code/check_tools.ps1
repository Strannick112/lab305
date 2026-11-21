# Конфигурация
. "$PSScriptRoot\..\config\config.ps1"
. $PSScriptRoot\..\..\Invoke-OnAll.ps1

Invoke-OnAll {        
    # Проверяем VMware Tools
    $result = & $vmrunPath getGuestIPAddress $vmxPath 2>&1
    
    if ($result -match "^\d+\.\d+\.\d+\.\d+$") {
        Write-Host "✅ VMware Tools установлены. IP: $result" -ForegroundColor Green
    } else {
        Write-Host "❌ VMware Tools НЕ установлены или не работают" -ForegroundColor Red
        Write-Host "   Ответ: $result" -ForegroundColor DarkGray
    }
}