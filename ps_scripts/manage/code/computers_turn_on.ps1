
$list = Import-Csv "$PSScriptRoot\..\..\config\pcs.csv"
$script:cred = $null


function Get-Cred {
    if (-not $script:cred) {
        $script:cred = Get-Credential -UserName "$PSScriptRoot\admin" -Message 'Пароль локального админа'
    }
    $script:cred
}

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

function Start-All($list) {
    foreach ($p in $list) { 
        Send-WOL $p.mac 
    }
    Write-Host "Пакеты отправлены: $(@($list).Count). Компьютеры загрузятся через 1-3 минуты (пункт 4 покажет статус)."
}

function Invoke-OnAll($list, [scriptblock]$sb, $arg) {
    $on = @((Get-Online $list | Where-Object online).ip)
    if (-not $on) { Write-Host 'Нет доступных компьютеров'; return }
    Invoke-Command -ComputerName $on -Credential (Get-Cred) -ScriptBlock $sb -ArgumentList $arg -ErrorAction Continue
}