```powershell
﻿# encoding: utf-8
<#
.SYNOPSIS
    A7_Port_Scanner - 危險端口全面掃描與封鎖模塊
    此腳本用於掃描 Windows 系統上的危險端口，檢測其監聽狀態、對應進程及防火牆規則，並提供封鎖未授權端口的功能。

.DESCRIPTION
    本模塊旨在增強 Windows 系統的網路安全防護。它會掃描一系列預定義的高危端口，
    識別任何未經授權的監聽服務，並可選擇性地配置防火牆規則以封鎖這些端口。
    腳本支援詳細日誌記錄、進度顯示、WhatIf/Confirm 機制，並生成 JSON 格式的檢測報告。

.PARAMETER WhatIf
    模擬執行操作，顯示將會執行的動作，但不會實際修改系統。

.PARAMETER Confirm
    在執行任何修改操作前，提示使用者確認。

.EXAMPLE
    .'A7_Port_Scanner - 危險端口全面掃描與封鎖模塊.ps1' -WhatIf
    # 模擬掃描並顯示將會執行的動作，不實際修改系統。

.EXAMPLE
    .'A7_Port_Scanner - 危險端口全面掃描與封鎖模塊.ps1' -Confirm
    # 掃描並在執行封鎖操作前提示使用者確認。

.EXAMPLE
    .'A7_Port_Scanner - 危險端口全面掃描與封鎖模塊.ps1'
    # 執行掃描並自動封鎖未授權端口（如果腳本邏輯中包含自動封鎖）。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    需求：Windows PowerShell 5.1 或更高版本。
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param()

#region 函數定義

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level,

        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"
    Write-Output $LogEntry
    # 實際應用中可將日誌寫入文件
    # Add-Content -Path "A7_Port_Scanner.log" -Value $LogEntry
}

function Test-PortConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$Port,

        [Parameter(Mandatory=$false)]
        [string]$ComputerName = 'localhost',

        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 1
    )
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectTask = $tcpClient.ConnectAsync($ComputerName, $Port)
        $connectTask.Wait($TimeoutSeconds * 1000) | Out-Null

        if ($tcpClient.Connected) {
            $tcpClient.Close()
            return $true
        } else {
            $tcpClient.Close()
            return $false
        }
    } catch {
        Write-Log -Level DEBUG -Message "測試端口 $Port 連接時發生錯誤: $($_.Exception.Message)"
        return $false
    }
}

function Get-ListeningProcesses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$Port
    )
    try {
        # 獲取所有 TCP 連接，篩選出監聽狀態的指定端口
        $netstatOutput = netstat -ano | Select-String -Pattern "TCP\s+0\.0\.0\.0:$Port|TCP\s+\[::\]:$Port" | ForEach-Object { $_.ToString().Trim() }

        $processes = @()
        foreach ($line in $netstatOutput) {
            if ($line -match "LISTENING") {
                $parts = $line -split '\s+'
                $pid = $parts[-1]
                $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
                if ($process) {
                    $processes += [pscustomobject]@{ 
                        PID = $pid;
                        ProcessName = $process.ProcessName;
                        Path = $process.Path
                    }
                }
            }
        }
        return $processes | Select-Object -Unique PID, ProcessName, Path
    } catch {
        Write-Log -Level ERROR -Message "獲取端口 $Port 監聽進程時發生錯誤: $($_.Exception.Message)"
        return @()
    }
}

function Get-FirewallRuleStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$Port
    )
    try {
        $rules = Get-NetFirewallRule -Action Allow -Direction Inbound -Enabled True -ErrorAction SilentlyContinue | Where-Object {
            ($_.DisplayName -like "*$Port*" -or $_.Description -like "*$Port*") -and
            ($_.LocalPort -eq "$Port" -or $_.LocalPort -eq "Any")
        }
        if ($rules) {
            return $rules | Select-Object DisplayName, Description, Enabled, Action, Direction, LocalPort, RemotePort, Protocol, Group | ConvertTo-Json -Compress
        } else {
            return "無允許傳入規則"
        }
    } catch {
        Write-Log -Level ERROR -Message "獲取端口 $Port 防火牆規則時發生錯誤: $($_.Exception.Message)"
        return "錯誤: $($_.Exception.Message)"
    }
}

function Block-PortWithFirewall {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$true)]
        [int]$Port,

        [Parameter(Mandatory=$true)]
        [string]$RuleName
    )
    if ($PSCmdlet.ShouldProcess("端口 $Port", "封鎖端口 $Port")) {
        try {
            Write-Log -Level INFO -Message "嘗試封鎖端口 $Port，規則名稱：$RuleName"
            # 檢查規則是否已存在，避免重複創建
            if (-not (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue)) {
                New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Action Block -Protocol TCP -LocalPort $Port -ErrorAction Stop | Out-Null
                Write-Log -Level INFO -Message "成功創建防火牆規則 $RuleName 以封鎖端口 $Port。"
                return $true
            } else {
                Write-Log -Level INFO -Message "防火牆規則 $RuleName 已存在，無需重複創建。"
                return $true
            }
        } catch {
            Write-Log -Level ERROR -Message "封鎖端口 $Port 時發生錯誤: $($_.Exception.Message)"
            return $false
        }
    }
    return $false
}

#endregion

#region 主邏輯

Write-Log -Level INFO -Message "A7_Port_Scanner 模塊啟動：開始掃描危險端口。"

# 定義高危端口清單
$HighRiskPorts = @(
    @{ Port = 21; Name = "FTP" },
    @{ Port = 22; Name = "SSH" },
    @{ Port = 23; Name = "Telnet" },
    @{ Port = 25; Name = "SMTP" },
    @{ Port = 53; Name = "DNS" },
    @{ Port = 80; Name = "HTTP" },
    @{ Port = 110; Name = "POP3" },
    @{ Port = 135; Name = "MS-RPC" },
    @{ Port = 137; Name = "NetBIOS-NS" },
    @{ Port = 138; Name = "NetBIOS-DGM" },
    @{ Port = 139; Name = "NetBIOS-SSN" },
    @{ Port = 143; Name = "IMAP" },
    @{ Port = 443; Name = "HTTPS" },
    @{ Port = 445; Name = "SMB" },
    @{ Port = 1433; Name = "MSSQL" },
    @{ Port = 1900; Name = "UPnP/SSDP" },
    @{ Port = 3306; Name = "MySQL" },
    @{ Port = 3389; Name = "RDP" },
    @{ Port = 5353; Name = "mDNS" },
    @{ Port = 5985; Name = "WinRM-HTTP" },
    @{ Port = 5986; Name = "WinRM-HTTPS" },
    @{ Port = 8080; Name = "HTTP-Proxy" }
)

$ScanResults = @()
$TotalPorts = $HighRiskPorts.Count
$CurrentPortIndex = 0

foreach ($PortInfo in $HighRiskPorts) {
    $CurrentPortIndex++
    $Port = $PortInfo.Port
    $PortName = $PortInfo.Name

    Write-Progress -Activity "掃描危險端口" -Status "正在掃描端口 $Port ($PortName)..." -PercentComplete (($CurrentPortIndex / $TotalPorts) * 100)
    Write-Log -Level INFO -Message "開始掃描端口 $Port ($PortName)..."

    $IsListening = Test-PortConnection -Port $Port
    $ListeningProcesses = @()
    $FirewallStatus = "無相關規則"
    $Blocked = $false

    if ($IsListening) {
        Write-Log -Level WARN -Message "端口 $Port ($PortName) 正在監聽！"
        $ListeningProcesses = Get-ListeningProcesses -Port $Port
        $FirewallStatus = Get-FirewallRuleStatus -Port $Port

        # 嘗試封鎖未授權的監聽端口
        # 這裡的邏輯可以根據實際需求調整，例如：
        # 1. 如果是預期服務，則不封鎖。
        # 2. 如果是未知進程，則自動封鎖。
        # 為了演示，我們假設所有高危端口的監聽都是潛在的未授權，並嘗試封鎖。
        $RuleName = "SafeModeDefender_Block_Port_$Port"
        if ($PSCmdlet.ShouldProcess("端口 $Port ($PortName) 正在監聽，是否封鎖？", "封鎖端口 $Port ($PortName)")) {
            $Blocked = Block-PortWithFirewall -Port $Port -RuleName $RuleName
        }
    } else {
        Write-Log -Level INFO -Message "端口 $Port ($PortName) 未監聽。"
        $FirewallStatus = Get-FirewallRuleStatus -Port $Port # 即使未監聽，也檢查是否有允許規則
    }

    $ScanResults += [pscustomobject]@{ 
        Port = $Port;
        PortName = $PortName;
        IsListening = $IsListening;
        ListeningProcesses = $ListeningProcesses;
        FirewallRuleStatus = $FirewallStatus;
        BlockedByScript = $Blocked
    }
}

Write-Progress -Activity "掃描危險端口" -Status "掃描完成。" -PercentComplete 100 -Completed
Write-Log -Level INFO -Message "危險端口掃描完成。"

# 生成 JSON 格式的檢測報告
$ReportPath = "$PSScriptRoot\A7_Port_Scanner_Report.json"
try {
    $ScanResults | ConvertTo-Json -Depth 10 | Set-Content -Path $ReportPath -Encoding UTF8 -Force
    Write-Log -Level INFO -Message "檢測報告已生成至：$ReportPath"
} catch {
    Write-Log -Level ERROR -Message "生成 JSON 報告時發生錯誤: $($_.Exception.Message)"
}

Write-Log -Level INFO -Message "A7_Port_Scanner 模塊執行結束。"

# 輸出報告內容到控制台
$ScanResults | Format-Table -AutoSize

```
