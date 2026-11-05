# class.ps1 - управление компьютерами аудитории
# Запуск: PowerShell от администратора ->  C:\class.ps1
# Нужен файл C:\pcs.csv со столбцами ip,mac

$pcs = Import-Csv 'C:\pcs.csv'
$script:cred = $null

function Get-Cred {
    if (-not $script:cred) {
        $script:cred = Get-Credential -UserName '.\admin' -Message 'Пароль локального админа'
    }
    $script:cred
}

function Select-PCs {
    $r = Read-Host 'Какие компьютеры? Диапазон последних цифр IP, например 11-24 (Enter = все)'
    if ([string]::IsNullOrWhiteSpace($r)) { return $pcs }
    if ($r -match '^(\d+)-(\d+)$') { $a = [int]$Matches[1]; $b = [int]$Matches[2] }
    elseif ($r -match '^\d+$')     { $a = [int]$r; $b = $a }
    else { Write-Host 'Не понял, беру всех'; return $pcs }
    $pcs | Where-Object { $n = [int]($_.ip.Split('.')[-1]); $n -ge $a -and $n -le $b }
}

function Send-WOL($mac) {
    $hex = $mac -replace '[-:]', ''
    $mb  = [byte[]]::new(6)
    for ($i = 0; $i -lt 6; $i++) { $mb[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16) }
    $pkt = [byte[]](@(0xFF) * 6 + ($mb * 16))
    $u = New-Object Net.Sockets.UdpClient
    $u.EnableBroadcast = $true
    [void]$u.Send($pkt, $pkt.Length, '192.168.35.255', 9)
    $u.Close()
}

# Проверка порта WinRM (5985) на всех сразу
function Get-Online($list) {
    $tasks = foreach ($p in $list) {
        $c = New-Object Net.Sockets.TcpClient
        [pscustomobject]@{ PC = $p; Client = $c; Task = $c.ConnectAsync($p.ip, 5985) }
    }
    Start-Sleep -Milliseconds 1500
    foreach ($t in $tasks) {
        $ok = $t.Task.IsCompleted -and -not $t.Task.IsFaulted -and -not $t.Task.IsCanceled -and $t.Client.Connected
        $t.Client.Close()
        [pscustomobject]@{ ip = $t.PC.ip; mac = $t.PC.mac; online = $ok }
    }
}

function Show-Status($list) {
    $st = Get-Online $list
    $on = @($st | Where-Object online)
    Write-Host ("Включено и доступно: {0} из {1}" -f $on.Count, @($list).Count) -ForegroundColor Green
    $off = @($st | Where-Object { -not $_.online })
    if ($off) { Write-Host ('Не отвечают: ' + (($off.ip | ForEach-Object { $_.Split('.')[-1] }) -join ', ')) -ForegroundColor Yellow }
}

function Start-All($list) {
    foreach ($p in $list) { Send-WOL $p.mac }
    Write-Host "Пакеты отправлены: $(@($list).Count). Компьютеры загрузятся через 1-3 минуты (пункт 4 покажет статус)."
}

function Invoke-OnAll($list, [scriptblock]$sb, $arg) {
    $on = @((Get-Online $list | Where-Object online).ip)
    if (-not $on) { Write-Host 'Нет доступных компьютеров'; return }
    Invoke-Command -ComputerName $on -Credential (Get-Cred) -ScriptBlock $sb -ArgumentList $arg -ErrorAction Continue
}

function Stop-All($list) {
    $n = @((Get-Online $list | Where-Object online)).Count
    if ((Read-Host "Выключить $n компьютеров? (y/n)") -ne 'y') { return }
    Invoke-OnAll $list { Stop-Computer -Force } | Out-Null
    Write-Host 'Команда выключения отправлена.'
}

function Restart-All($list) {
    $n = @((Get-Online $list | Where-Object online)).Count
    if ((Read-Host "Перезагрузить $n компьютеров? (y/n)") -ne 'y') { return }
    Invoke-OnAll $list { Restart-Computer -Force } | Out-Null
    Write-Host 'Команда перезагрузки отправлена.'
}

function Start-Console($list) {
    $on = @((Get-Online $list | Where-Object online).ip)
    if (-not $on) { Write-Host 'Нет доступных компьютеров'; return }
    $s = New-PSSession -ComputerName $on -Credential (Get-Cred) -ErrorAction SilentlyContinue
    Write-Host ("Подключено {0} из {1}. Команда уходит на все. Для выхода: exit" -f @($s).Count, @($list).Count) -ForegroundColor Green
    while ($true) {
        $cmd = Read-Host 'ALL>'
        if ($cmd -eq 'exit') { break }
        if ([string]::IsNullOrWhiteSpace($cmd)) { continue }
        Invoke-Command -Session $s -ScriptBlock { param($c) Invoke-Expression $c } -ArgumentList $cmd -ErrorAction Continue |
            Sort-Object PSComputerName |
            ForEach-Object { "[{0}] {1}" -f $_.PSComputerName, ($_ | Out-String).Trim() }
    }
    Remove-PSSession $s
}

# Настройка Wake-on-LAN в Windows (BIOS настраивается вручную)
function Set-WolWindows($list) {
    $res = Invoke-OnAll $list {
        Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0
        Set-NetAdapterPowerManagement -Name 'Ethernet' -WakeOnMagicPacket Enabled -WakeOnPattern Disabled -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name 'Ethernet' -DisplayName 'Wake on Magic Packet' -DisplayValue 'Enabled' -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name 'Ethernet' -DisplayName 'Shutdown Wake-On-Lan' -DisplayValue 'Enabled' -ErrorAction SilentlyContinue
        $pm = Get-NetAdapterPowerManagement -Name 'Ethernet'
        "{0}: WakeOnMagicPacket={1}" -f $env:COMPUTERNAME, $pm.WakeOnMagicPacket
    }
    $res | Sort-Object
}

# Меню
while ($true) {
    Write-Host ''
    Write-Host '=== Управление аудиторией ===' -ForegroundColor Cyan
    Write-Host '1  Включить (Wake-on-LAN)'
    Write-Host '2  Выключить'
    Write-Host '3  Перезагрузить'
    Write-Host '4  Статус (кто включён)'
    Write-Host '5  Консоль на всех компьютерах'
    Write-Host '6  Настроить WoL в Windows (один раз)'
    Write-Host '0  Выход'
    $c = Read-Host 'Выбор'
    if ($c -eq '0') { break }
    if ($c -notin '1','2','3','4','5','6') { continue }
    $list = Select-PCs
    switch ($c) {
        '1' { Start-All $list }
        '2' { Stop-All $list }
        '3' { Restart-All $list }
        '4' { Show-Status $list }
        '5' { Start-Console $list }
        '6' { Set-WolWindows $list }
    }
}
