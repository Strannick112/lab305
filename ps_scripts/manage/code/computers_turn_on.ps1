
$list = Import-Csv "$PSScriptRoot\..\..\config\pcs.csv"
$script:cred = $null

# Write-Host "list: $list, path: $PSScriptRoot\..\..\config\pcs.csv"

function Get-Cred {
    if (-not $script:cred) {
        $script:cred = Get-Credential -UserName "$PSScriptRoot\admin" -Message 'Пароль локального админа'
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

function Start-All() {
    foreach ($p in $list) { 
        Send-WOL $p.mac 
    }
    Write-Host "Пакеты отправлены: $(@($list).Count). Компьютеры загрузятся через 1-3 минуты"
}

function Invoke-OnAll($list, [scriptblock]$sb, $arg) {
    $on = @((Get-Online $list | Where-Object online).ip)
    if (-not $on) { Write-Host 'Нет доступных компьютеров'; return }
    Invoke-Command -ComputerName $on -Credential (Get-Cred) -ScriptBlock $sb -ArgumentList $arg -ErrorAction Continue
}
