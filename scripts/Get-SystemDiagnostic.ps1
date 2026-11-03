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

$rede = Get-NetworkSummary

Get-SystemSummary | Format-List
Get-DiskSummary   | Format-Table -AutoSize
$rede             | Format-List
Test-ConnectivityLadder -Gateway $rede.Gateway | Format-Table -AutoSize
Get-CriticalServices | Format-Table -AutoSize
Get-RecentErrors     | Format-Table -AutoSize