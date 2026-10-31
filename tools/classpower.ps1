# classpower.ps1 - включение, выключение, перезагрузка и статус компьютеров аудитории
#
# Без параметров открывается МЕНЮ:   .\classpower.ps1
# С параметрами (для автоматизации и сайта):
#   .\classpower.ps1 -Action Status
#   .\classpower.ps1 -Action On
#   .\classpower.ps1 -Action Off -Range 11-24
#   .\classpower.ps1 -Action Restart -Range 33 -Yes
#
# Таблица ip,mac хранится локально: C:\scripts\pcs.csv (в репозиторий не заливается).
# Другая папка: переменная среды CLASS_DATA или параметр -Csv.
#
# Пароль админа: переменная среды CLASS_ADMIN_PASSWORD (для запуска с сайта),
# если её нет - окно запроса. В репозиторий пароль НЕ кладём.
#
# Для сайта:  -Action Status -Json   (вернёт JSON: ip и online, без MAC)
#             добавляйте -Yes -NoPrompt, чтобы скрипт ничего не спрашивал
#             (для Off/Restart тогда нужна переменная среды CLASS_ADMIN_PASSWORD)

param(
    [ValidateSet('On', 'Off', 'Restart', 'Status')]
    [string]$Action = '',
    [string]$Range = '',
    [string]$Csv = '',
    [string]$Broadcast = '192.168.35.255',
    [switch]$Yes,
    [switch]$NoPrompt,
    [switch]$Json
)

. "$PSScriptRoot\common.ps1"
try { $all = @(Get-PcsTable -Csv $Csv) } catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }

$script:cred   = $null
$script:failed = $false

function Send-WOL($mac) {
    $hex = $mac -replace '[-:]', ''
    $mb  = [byte[]]::new(6)
    for ($i = 0; $i -lt 6; $i++) { $mb[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16) }
    $pkt = [byte[]](@(0xFF) * 6 + ($mb * 16))
    $u = New-Object Net.Sockets.UdpClient
    $u.EnableBroadcast = $true
    [void]$u.Send($pkt, $pkt.Length, $Broadcast, 9)
    $u.Close()
}

# Быстрая проверка порта WinRM у всех сразу
function Get-Online($list) {
    $tasks = foreach ($p in $list) {
        $c = New-Object Net.Sockets.TcpClient
        [pscustomobject]@{ PC = $p; Client = $c; Task = $c.ConnectAsync($p.ip, 5985) }
    }
    Start-Sleep -Milliseconds 2000
    foreach ($t in $tasks) {
        $ok = $t.Task.IsCompleted -and -not $t.Task.IsFaulted -and -not $t.Task.IsCanceled -and $t.Client.Connected
        $t.Client.Close()
        [pscustomobject]@{ ip = $t.PC.ip; mac = $t.PC.mac; online = $ok }
    }
}

function Short($ip) { $ip.Split('.')[-1] }

function Get-AdminCred {
    if ($script:cred) { return $script:cred }
    if ($env:CLASS_ADMIN_PASSWORD) {
        $sec = ConvertTo-SecureString $env:CLASS_ADMIN_PASSWORD -AsPlainText -Force
        $script:cred = New-Object System.Management.Automation.PSCredential('.\Admin', $sec)
        return $script:cred
    }
    if ($NoPrompt) { throw 'Не задана переменная среды CLASS_ADMIN_PASSWORD' }
    $script:cred = Get-Credential -UserName '.\Admin' -Message 'Пароль админа'
    $script:cred
}

# Выбор компьютеров по диапазону последних цифр IP: 11-24 или 33 (пусто = все)
function Select-Range($rng) {
    if (-not $rng) { return $all }
    if ($rng -match '^(\d+)-(\d+)$') { $a = [int]$Matches[1]; $b = [int]$Matches[2] }
    elseif ($rng -match '^\d+$')     { $a = [int]$rng; $b = $a }
    else { Write-Host 'Диапазон должен быть вида 11-24 или 33' -ForegroundColor Red; return $null }
    @($all | Where-Object { $n = [int]($_.ip.Split('.')[-1]); $n -ge $a -and $n -le $b })
}

function Invoke-Action($act, $list) {
    switch ($act) {

        'Status' {
            $st = @(Get-Online $list)
            if ($Json) {
                ConvertTo-Json -InputObject @($st | ForEach-Object { [pscustomobject]@{ ip = $_.ip; online = $_.online } }) -Compress
                return
            }
            $on  = @($st | Where-Object online)
            $off = @($st | Where-Object { -not $_.online })
            Write-Host ("Включено и доступно: {0} из {1}" -f $on.Count, @($list).Count) -ForegroundColor Green
            if ($off) { Write-Host ('Не отвечают: ' + (($off.ip | ForEach-Object { Short $_ }) -join ', ')) -ForegroundColor Yellow }
        }

        'On' {
            foreach ($p in $list) { Send-WOL $p.mac }
            Write-Host ("Пакеты Wake-on-LAN отправлены: {0}. Загрузка займёт 1-3 минуты." -f @($list).Count) -ForegroundColor Green
            Write-Host 'Проверить результат: пункт "Статус".'
        }

        { $_ -in 'Off', 'Restart' } {
            $on = @(Get-Online $list | Where-Object online)
            if (-not $on) { Write-Host 'Нет включённых компьютеров'; return }
            $word = if ($act -eq 'Off') { 'Выключить' } else { 'Перезагрузить' }
            if (-not $Yes) {
                if ((Read-Host "$word $($on.Count) компьютеров? (y/n)") -ne 'y') { Write-Host 'Отменено'; return }
            }
            try { $cred = Get-AdminCred } catch { Write-Host $_.Exception.Message -ForegroundColor Red; $script:failed = $true; return }
            $opt = New-PSSessionOption -OpenTimeout 10000 -OperationTimeout 20000 -NoMachineProfile
            $sb  = if ($act -eq 'Off') { { Stop-Computer -Force } } else { { Restart-Computer -Force } }
            $err = $null
            Invoke-Command -ComputerName $on.ip -Credential $cred -SessionOption $opt -ThrottleLimit 32 -ScriptBlock $sb -ErrorAction SilentlyContinue -ErrorVariable err | Out-Null
            $failedIps = @($err | ForEach-Object { $_.TargetObject } | Where-Object { $_ } | Select-Object -Unique)
            if ($failedIps.Count -ge $on.Count) { $script:cred = $null }   # вероятно неверный пароль: спросим заново
            Write-Host ("Команда отправлена: {0}" -f ($on.Count - $failedIps.Count)) -ForegroundColor Green
            if ($failedIps) { Write-Host ('Не прошло (вход/сеть): ' + (($failedIps | ForEach-Object { Short $_ }) -join ', ')) -ForegroundColor Yellow }
        }
    }
}

# ---------- Режим с параметрами ----------
if ($Action) {
    $list = Select-Range $Range
    if (-not $list) { Write-Host 'Нет компьютеров в выбранном диапазоне'; exit 1 }
    Invoke-Action $Action $list
    if ($script:failed) { exit 1 }
    return
}

# ---------- Меню ----------
while ($true) {
    Write-Host ''
    Write-Host '=== Питание компьютеров аудитории ===' -ForegroundColor Cyan
    Write-Host '1  Включить (Wake-on-LAN)'
    Write-Host '2  Выключить'
    Write-Host '3  Перезагрузить'
    Write-Host '4  Статус (кто включён)'
    Write-Host '0  Выход'
    $c = Read-Host 'Выбор'
    if ($c -eq '0') { break }
    $act = switch ($c) { '1' { 'On' } '2' { 'Off' } '3' { 'Restart' } '4' { 'Status' } default { $null } }
    if (-not $act) { continue }
    $r = Read-Host 'Какие компьютеры? Диапазон последних цифр IP, например 11-24 (Enter = все)'
    $list = Select-Range $r
    if (-not $list) { Write-Host 'Нет компьютеров в выбранном диапазоне'; continue }
    Invoke-Action $act $list
}
