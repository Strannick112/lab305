# config.ps1
# ВАЖНО: Добавьте этот файл в .gitignore!

# Настройки vmware

$Global:vmName = "demo305"
$Global:vmxPath = "C:\Users\Student\Documents\Virtual Machines\demo305\demo305.vmx"
$vmPath = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
$vm_x64_path = "C:\Program Files\VMware\VMware Workstation\vmrun.exe"

$Global:vmrunPath = $vmPath
if (-Not (Test-Path $Global:vmrunPath)) {
    $Global:vmrunPath = $vm_x64_path
}

if (-Not (Test-Path $Global:vmrunPath)) {
    Write-Error "Не удалось найти vmrun.exe. Проверьте установку VMware Workstation."
    exit 1
}
