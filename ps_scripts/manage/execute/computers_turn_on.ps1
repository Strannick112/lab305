cd ..\..
. .\class.ps1

Invoke-OnAll { Start-All $list } 
cd .\manage\execute