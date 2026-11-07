cd ..\..
. .\Invoke-OnAll.ps1

Invoke-OnAll { Stop-Computer -Force } 
cd .\manage\execute