<#
.SYNOPSIS
    Очистка рабочего стола: удаляется всё, кроме ярлыков (.lnk, .url).
.DESCRIPTION
    Папки на рабочем столе удаляются целиком. Служебный desktop.ini сохраняется.
    Поддерживает -WhatIf. Возвращает сводку, совместимую с Invoke-RemoteClean.
.EXAMPLE
    .\Clean-Desktop.ps1 -WhatIf
    .\Clean-Desktop.ps1
    .\Clean-Desktop.ps1 -DesktopPath 'C:\Users\Student\Desktop' -IncludePublicDesktop
#>
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$DesktopPath = 'C:\Users\Student\Desktop',
    [switch]$IncludePublicDesktop,                      # чистить ещё и C:\Users\Public\Desktop
    [string[]]$KeepExtensions = @('.lnk', '.url', '.exe')       # что считается ярлыком
)

$ErrorActionPreference = 'Stop'

function Format-Size([long]$Bytes) {
    if ($Bytes -ge 1GB) { '{0:N2} GB' -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { '{0:N2} MB' -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { '{0:N2} KB' -f ($Bytes / 1KB) }
    else { "$Bytes B" }
}

# Обход дерева БЕЗ входа в symlink/junction (важно для PS 5.1)
function Get-ItemsSafe([string]$Root) {
    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push($Root)
    while ($stack.Count -gt 0) {
        foreach ($i in (Get-ChildItem -LiteralPath $stack.Pop() -Force -ErrorAction SilentlyContinue)) {
            $i
            if ($i.PSIsContainer -and -not ($i.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                $stack.Push($i.FullName)
            }
        }
    }
}

$roots = @($DesktopPath)
if ($IncludePublicDesktop) { $roots += (Join-Path $env:Public 'Desktop') }

$success = 0; $errors = 0; $kept = 0; [long]$bytes = 0
$keepExt = @($KeepExtensions | ForEach-Object { $_.ToLower() })

foreach ($root in $roots) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        Write-Host "Папка не найдена: $root" -ForegroundColor Yellow
        continue
    }
    Write-Host "Очистка: $root" -ForegroundColor Cyan

    foreach ($item in (Get-ChildItem -LiteralPath $root -Force)) {
        $isKeep = (-not $item.PSIsContainer -and $keepExt -contains $item.Extension.ToLower()) -or
                  ($item.Name -eq 'desktop.ini')
        if ($isKeep) { $kept++; continue }

        # размер считаем ДО удаления
        [long]$size = 0
        if ($item.PSIsContainer) {
            if (-not ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                $size = [long]((Get-ItemsSafe $item.FullName |
                    Where-Object { -not $_.PSIsContainer } |
                    Measure-Object -Property Length -Sum).Sum)
            }
        } else { $size = $item.Length }

        if ($WhatIfPreference) {
            Write-Host ("[WHATIF] Удалил бы: {0} ({1})" -f $item.FullName, (Format-Size $size)) -ForegroundColor Yellow
            $success++; $bytes += $size
            continue
        }

        if ($PSCmdlet.ShouldProcess($item.FullName, 'Удалить')) {
            try {
                if ($item.PSIsContainer -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                    # удаляем только саму ссылку на папку, НЕ её содержимое
                    [System.IO.Directory]::Delete($item.FullName, $false)
                } else {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                }
                Write-Host ("Удалено: {0} ({1})" -f $item.FullName, (Format-Size $size)) -ForegroundColor Gray
                $success++; $bytes += $size
            } catch {
                Write-Host ("ОШИБКА: {0} -- {1}" -f $item.FullName, $_.Exception.Message) -ForegroundColor Red
                $errors++
            }
        }
    }
}

$label = if ($WhatIfPreference) { 'Предпросмотр' } else { 'Итог' }
Write-Host ("{0}: удалено {1}, ошибок {2}, оставлено ярлыков {3}, освобождено {4}" -f `
    $label, $success, $errors, $kept, (Format-Size $bytes)) -ForegroundColor Green

[pscustomobject]@{
    ComputerName = $env:COMPUTERNAME
    SuccessCount = $success
    ErrorCount   = $errors
    TotalBytes   = $bytes
    TotalSize    = Format-Size $bytes
    KeptCount    = $kept
}