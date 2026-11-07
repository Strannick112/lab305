$cred = Get-Credential   # .\admin
$pcs  = 11..24 | ForEach-Object { "192.168.35.$_" }
$gw   = Get-Content "..\..\config\gateway.txt"

cd ..\..
. .\Invoke-OnAll.ps1

Invoke-Command -ComputerName $pcs -Credential $cred -ArgumentList $gw -ScriptBlock {
    param($gw)
    Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false
    if ($gw) { New-NetRoute -DestinationPrefix "0.0.0.0/0" -InterfaceAlias "Ethernet" -NextHop $gw | Out-Null }
    "{0}: {1}" -f $env:COMPUTERNAME, ((Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop -join ',')
}
cd .\manage\execute