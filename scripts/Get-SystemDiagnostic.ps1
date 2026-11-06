$ProgressPreference = 'SilentlyContinue'

function Get-SystemSummary {
    $os     = Get-CimInstance Win32_OperatingSystem
    $cpu    = Get-CimInstance Win32_Processor | Select-Object -First 1
    $uptime = (Get-Date) - $os.LastBootUpTime

    [PSCustomObject]@{
        Computador  = $env:COMPUTERNAME
        Sistema     = $os.Caption
        Versao      = $os.Version
        UptimeDias  = [math]::Round($uptime.TotalDays, 1)
        Processador = $cpu.Name
        Nucleos     = $cpu.NumberOfCores
        RamTotalGB  = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        RamLivreGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    }
}

function Get-DiskSummary {
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
        Select-Object DeviceID,
            @{Name='TamanhoGB'; Expression={[math]::Round($_.Size / 1GB, 1)}},
            @{Name='LivreGB';   Expression={[math]::Round($_.FreeSpace / 1GB, 1)}},
            @{Name='LivrePct';  Expression={[math]::Round(($_.FreeSpace / $_.Size) * 100, 1)}}
}

function Get-NetworkSummary {
    $cfg = Get-NetIPConfiguration |
        Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq 'Up' } |
        Select-Object -First 1

    if (-not $cfg) {
        return [PSCustomObject]@{ Interface = 'nenhuma ativa'; IPv4 = ''; Gateway = ''; DNS = '' }
    }

    [PSCustomObject]@{
        Interface = $cfg.InterfaceAlias
        IPv4      = ($cfg.IPv4Address.IPAddress -join ', ')
        Gateway   = $cfg.IPv4DefaultGateway.NextHop
        DNS       = (($cfg.DNSServer.ServerAddresses | Select-Object -Unique) -join ', ')
    }
}

function New-TestResult {
    param([string]$Teste, [string]$Alvo, [bool]$Ok)
    [PSCustomObject]@{ Teste = $Teste; Alvo = $Alvo; Ok = $Ok }
}

function Test-ConnectivityLadder {
    param([string]$Gateway)

    $resultados = @()

    if ($Gateway) {
        $r = Test-NetConnection -ComputerName $Gateway -WarningAction SilentlyContinue
        $resultados += New-TestResult 'Gateway (ping)' $Gateway $r.PingSucceeded
    }

    $r = Test-NetConnection -ComputerName 8.8.8.8 -WarningAction SilentlyContinue
    $resultados += New-TestResult 'Internet por IP (ping)' '8.8.8.8' $r.PingSucceeded

    try {
        Resolve-DnsName google.com -Type A -ErrorAction Stop | Out-Null
        $ok = $true
    } catch { $ok = $false }
    $resultados += New-TestResult 'DNS do sistema' 'google.com' $ok

    try {
        Resolve-DnsName google.com -Type A -Server 8.8.8.8 -ErrorAction Stop | Out-Null
        $ok = $true
    } catch { $ok = $false }
    $resultados += New-TestResult 'DNS publico' 'google.com via 8.8.8.8' $ok

    $r = Test-NetConnection -ComputerName google.com -Port 443 -WarningAction SilentlyContinue
    $resultados += New-TestResult 'HTTPS (porta 443)' 'google.com' $r.TcpTestSucceeded

    $resultados
}

function Get-CriticalServices {
    $nomes = 'Dnscache', 'Dhcp', 'WlanSvc', 'EventLog', 'Winmgmt',
             'mpssvc', 'WinDefend', 'Spooler', 'LanmanWorkstation'

    foreach ($nome in $nomes) {
        $s = Get-Service -Name $nome -ErrorAction SilentlyContinue
        if ($s) {
            [PSCustomObject]@{
                Servico = $s.Name
                Nome    = $s.DisplayName
                Status  = [string]$s.Status
                Inicio  = [string]$s.StartType
            }
        } else {
            [PSCustomObject]@{
                Servico = $nome
                Nome    = '(nao encontrado)'
                Status  = 'NaoEncontrado'
                Inicio  = ''
            }
        }
    }
}

function Get-RecentErrors {
    param([int]$Horas = 24, [int]$Quantidade = 15)

    $filtro = @{
        LogName   = 'System', 'Application'
        Level     = 1, 2
        StartTime = (Get-Date).AddHours(-$Horas)
    }

    Get-WinEvent -FilterHashtable $filtro -MaxEvents 200 -ErrorAction SilentlyContinue |
        Sort-Object TimeCreated -Descending |
        Select-Object -First $Quantidade |
        Select-Object @{Name='Hora';     Expression={$_.TimeCreated.ToString('dd/MM HH:mm')}},
                      @{Name='Origem';   Expression={$_.ProviderName}},
                      @{Name='Id';       Expression={$_.Id}},
                      @{Name='Mensagem'; Expression={
                          $m = ([string]$_.Message -split '\r?\n')[0]
                          if ($m.Length -gt 70) { $m.Substring(0, 67) + '...' } else { $m }
                      }}
}

function New-Finding {
    param([string]$Nivel, [string]$Item, [string]$Detalhe)
    [PSCustomObject]@{ Nivel = $Nivel; Item = $Item; Detalhe = $Detalhe }
}

function Get-Findings {
    param($Sistema, $Discos, $Testes, $Servicos, $Erros)

    $f = @()

    foreach ($d in @($Discos)) {
        $txt = "$($d.DeviceID) com $($d.LivrePct)% livre ($($d.LivreGB) GB)"
        if     ($d.LivrePct -lt 10) { $f += New-Finding 'CRITICO' 'Disco' $txt }
        elseif ($d.LivrePct -lt 20) { $f += New-Finding 'ATENCAO' 'Disco' $txt }
        else                        { $f += New-Finding 'OK' 'Disco' $txt }
    }

    $ramPct = [math]::Round(($Sistema.RamLivreGB / $Sistema.RamTotalGB) * 100, 1)
    $txt = "$ramPct% livre ($($Sistema.RamLivreGB) GB de $($Sistema.RamTotalGB) GB)"
    if     ($ramPct -lt 10) { $f += New-Finding 'CRITICO' 'Memoria' $txt }
    elseif ($ramPct -lt 20) { $f += New-Finding 'ATENCAO' 'Memoria' $txt }
    else                    { $f += New-Finding 'OK' 'Memoria' $txt }

    if ($Sistema.UptimeDias -gt 14) {
        $f += New-Finding 'ATENCAO' 'Uptime' "$($Sistema.UptimeDias) dias sem reiniciar"
    } else {
        $f += New-Finding 'OK' 'Uptime' "$($Sistema.UptimeDias) dias desde o ultimo boot"
    }

    $falhas = @($Testes | Where-Object { -not $_.Ok })
    if ($falhas.Count -gt 0) {
        $f += New-Finding 'CRITICO' 'Conectividade' ('Falhou: ' + (($falhas | ForEach-Object { $_.Teste }) -join ', '))
    } else {
        $f += New-Finding 'OK' 'Conectividade' 'Todos os testes passaram'
    }

    $parados = @($Servicos | Where-Object { $_.Inicio -eq 'Automatic' -and $_.Status -ne 'Running' })
    if ($parados.Count -gt 0) {
        $f += New-Finding 'ATENCAO' 'Servicos' ('Parados: ' + (($parados | ForEach-Object { $_.Servico }) -join ', '))
    } else {
        $f += New-Finding 'OK' 'Servicos' 'Servicos criticos em execucao'
    }

    $n = @($Erros | Where-Object { $_ }).Count
    if ($n -ge 10) {
        $f += New-Finding 'ATENCAO' 'Eventos' "$n erros nas ultimas 24 h"
    } else {
        $f += New-Finding 'OK' 'Eventos' "$n erros nas ultimas 24 h"
    }

    $f
}

function ConvertTo-HtmlTable {
    param($Data, [scriptblock]$RowClass)

    $items = @($Data | Where-Object { $_ })
    if ($items.Count -eq 0) { return '<p class="vazio">Nenhum registro encontrado.</p>' }

    $cols = $items[0].PSObject.Properties.Name
    $html = '<table><thead><tr>'
    foreach ($c in $cols) {
        $html += '<th>' + [System.Net.WebUtility]::HtmlEncode($c) + '</th>'
    }
    $html += '</tr></thead><tbody>'

    foreach ($item in $items) {
        $cls = ''
        if ($RowClass) { $cls = & $RowClass $item }
        $html += '<tr class="' + $cls + '">'
        foreach ($c in $cols) {
            $html += '<td>' + [System.Net.WebUtility]::HtmlEncode([string]$item.$c) + '</td>'
        }
        $html += '</tr>'
    }

    $html + '</tbody></table>'
}

function New-HtmlReport {
    param($Sistema, $Rede, $Discos, $Testes, $Servicos, $Erros, $Achados)

    $css = 
@'
body{font-family:Segoe UI,Arial,sans-serif;margin:24px;color:#222}
h1{margin-bottom:0}
h2{margin-top:28px;border-bottom:2px solid #ddd;padding-bottom:4px}
.sub{color:#666;margin-top:4px}
table{border-collapse:collapse;width:100%;margin-top:8px;font-size:14px}
th,td{border:1px solid #ddd;padding:6px 10px;text-align:left}
th{background:#f3f3f3}
tr.ok td{background:#e8f6ec}
tr.atencao td{background:#fff4d6}
tr.critico td{background:#fde2e2}
.vazio{color:#666;font-style:italic}
'@

    $tResumo = ConvertTo-HtmlTable $Achados { param($i) $i.Nivel.ToLower() }
    $tSist   = ConvertTo-HtmlTable $Sistema
    $tDisco  = ConvertTo-HtmlTable $Discos { param($i) if ($i.LivrePct -lt 10) { 'critico' } elseif ($i.LivrePct -lt 20) { 'atencao' } else { 'ok' } }
    $tRede   = ConvertTo-HtmlTable $Rede
    $tTestes = ConvertTo-HtmlTable $Testes { param($i) if ($i.Ok) { 'ok' } else { 'critico' } }
    $tServ   = ConvertTo-HtmlTable $Servicos { param($i) if ($i.Status -eq 'Running') { 'ok' } elseif ($i.Inicio -eq 'Automatic') { 'atencao' } else { '' } }
    $tErros  = ConvertTo-HtmlTable $Erros
    $quando  = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'
@"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>Diagn&oacute;stico - $($Sistema.Computador)</title>
<style>$css</style>
</head>
<body>
<h1>Relat&oacute;rio de diagn&oacute;stico</h1>
<p class="sub">Computador: $($Sistema.Computador) &middot; Gerado em $quando</p>

<h2>Resumo</h2>
$tResumo

<h2>Sistema</h2>
$tSist

<h2>Disco</h2>
$tDisco

<h2>Rede</h2>
$tRede

<h2>Testes de conectividade</h2>
$tTestes

<h2>Servi&ccedil;os cr&iacute;ticos</h2>
$tServ

<h2>Erros recentes (&uacute;ltimas 24 h)</h2>
$tErros

<p class="sub">Gerado por Get-SystemDiagnostic.ps1 &middot; somente leitura, nada foi alterado no computador.</p>
</body>
</html>
"@
}

$sistema  = Get-SystemSummary
$discos   = @(Get-DiskSummary)
$rede     = Get-NetworkSummary
$testes   = @(Test-ConnectivityLadder -Gateway $rede.Gateway)
$servicos = @(Get-CriticalServices)
$erros    = @(Get-RecentErrors)
$achados  = @(Get-Findings -Sistema $sistema -Discos $discos -Testes $testes -Servicos $servicos -Erros $erros)

$achados | Format-Table -AutoSize

$html = New-HtmlReport -Sistema $sistema -Rede $rede -Discos $discos -Testes $testes -Servicos $servicos -Erros $erros -Achados $achados

$pasta = Join-Path (Split-Path -Parent $PSScriptRoot) 'reports'
if (-not (Test-Path $pasta)) { New-Item -ItemType Directory -Path $pasta | Out-Null }
$nome    = 'diagnostico-{0}-{1}.html' -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd-HHmm')
$arquivo = Join-Path $pasta $nome
$html | Set-Content -Path $arquivo -Encoding UTF8

Write-Host "Relatorio salvo em: $arquivo"
Invoke-Item $arquivo