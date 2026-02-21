<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>
<#
.SYNOPSIS
    A2_RDP_Security - RDP 服務安全強化模塊
    此腳本用於強化 Windows 系統的遠端桌面服務 (RDP) 安全配置，防範常見的 RDP 相關威脅。

.DESCRIPTION
    本腳本將執行以下安全強化操作：
    1. 檢測並強制啟用網路層級驗證 (NLA)。
    2. 審核 RDP 服務的啟用狀態，並提供禁用選項。
    3. 配置 Windows 防火牆規則，限制 RDP 端口 3389 的存取。
    4. 啟用 RDP 連接日誌審計。
    5. 審核並移除「遠端桌面使用者」群組中不必要的成員。
    6. 生成 JSON 格式的檢測報告。

.PARAMETER WhatIf
    描述在不實際執行任何更改的情況下，腳本將會執行的操作。

.PARAMETER Confirm
    在執行任何更改之前，提示使用者進行確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    需求：Windows 10 或更高版本，具備管理員權限。

    威脅來源：CVE-2026-21533 (RDP 權限提升)
    防護目標：端口 3389 (RDP), RDP 服務配置安全, 網路層級驗證 (NLA)
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact=\'High\')]
param()

#region 函數定義

# -----------------------------------------------------------------------------
# 函數：Write-Log
# 描述：用於多級別日誌記錄。
# 參數：
#   -Level：日誌級別 (Info, Warn, Error, Debug)
#   -Message：日誌訊息
# -----------------------------------------------------------------------------
function Write-Log {
    [CmdletBinding()]
    param(
        [ValidateSet(\'Info\', \'Warn\', \'Error\', \'Debug\')]
        [string]$Level = \'Info\',
        [string]$Message
    )
    $Timestamp = Get-Date -Format \"yyyy-MM-dd HH:mm:ss\"
    $LogEntry = \"[$Timestamp][$Level] $Message\"
    Write-Host $LogEntry
    # 實際應用中可將日誌寫入檔案
}

# -----------------------------------------------------------------------------
# 函數：Test-AdminPrivileges
# 描述：檢查腳本是否以管理員權限運行。
# -----------------------------------------------------------------------------
function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log -Level Error -Message \"此腳本需要管理員權限才能運行。請以管理員身份運行 PowerShell。\"
        exit 1
    }
}

# -----------------------------------------------------------------------------
# 函數：Get-RDPStatus
# 描述：獲取 RDP 服務的當前狀態和配置。
# -----------------------------------------------------------------------------
function Get-RDPStatus {
    $report = @{}

    # 1. RDP 服務是否啟用 (註冊表)
    try {
        $fDenyTSConnections = (Get-ItemProperty -Path \'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name \'fDenyTSConnections\' -ErrorAction Stop).fDenyTSConnections
        $report.RDPServiceEnabled = if ($fDenyTSConnections -eq 0) { $true } else { $false }
        Write-Log -Message \"RDP 服務啟用狀態：$($report.RDPServiceEnabled)\"
    }
    catch {
        Write-Log -Level Warn -Message \"無法獲取 RDP 服務啟用狀態：$($_.Exception.Message)\"
        $report.RDPServiceEnabled = \"未知\"
    }

    # 2. NLA 是否強制啟用 (註冊表)
    try {
        $UserAuthentication = (Get-ItemProperty -Path \'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name \'UserAuthentication\' -ErrorAction Stop).UserAuthentication
        $report.NLAForcedEnabled = if ($UserAuthentication -eq 1) { $true } else { $false }
        Write-Log -Message \"NLA 強制啟用狀態：$($report.NLAForcedEnabled)\"
    }
    catch {
        Write-Log -Level Warn -Message \"無法獲取 NLA 強制啟用狀態：$($_.Exception.Message)\"
        $report.NLAForcedEnabled = \"未知\"
    }

    # 3. 端口 3389 防火牆規則
    try {
        $firewallRule = Get-NetFirewallRule -DisplayName \"遠端桌面 (TCP-In)\" -ErrorAction SilentlyContinue
        if ($firewallRule) {
            $report.FirewallRule3389Enabled = $firewallRule.Enabled
            $report.FirewallRule3389Action = $firewallRule.Action
            $report.FirewallRule3389RemoteAddresses = ($firewallRule | Get-NetFirewallPortFilter).RemoteAddress
            Write-Log -Message \"防火牆規則 \'遠端桌面 (TCP-In)\' 狀態：啟用=$($report.FirewallRule3389Enabled), 動作=$($report.FirewallRule3389Action), 遠端地址=$($report.FirewallRule3389RemoteAddresses -join \', \')\"
        } else {
            $report.FirewallRule3389Enabled = $false
            $report.FirewallRule3389Action = \"無\"
            $report.FirewallRule3389RemoteAddresses = \"無\"
            Write-Log -Message \"未找到防火牆規則 \'遠端桌面 (TCP-In)\'。\"
        }
    }
    catch {
        Write-Log -Level Warn -Message \"無法獲取端口 3389 防火牆規則：$($_.Exception.Message)\"
        $report.FirewallRule3389Enabled = \"未知\"
        $report.FirewallRule3389Action = \"未知\"
        $report.FirewallRule3389RemoteAddresses = \"未知\"
    }

    # 4. RDP 連接日誌審計 (事件日誌配置)
    try {
        $auditPolicy = Get-WmiObject -Class Win32_AuditPolicy -Namespace root\cimv2\security\microsofttmm -ErrorAction Stop | Where-Object {$_.Category -eq \'Logon/Logoff\' -and $_.SubCategory -eq \'Remote Desktop Services\'}
        $report.RDPLogonAuditEnabled = if ($auditPolicy -and $auditPolicy.AuditPolicy -contains \'Success\') { $true } else { $false }
        Write-Log -Message \"RDP 連接日誌審計狀態：$($report.RDPLogonAuditEnabled)\"
    }
    catch {
        Write-Log -Level Warn -Message \"無法獲取 RDP 連接日誌審計狀態：$($_.Exception.Message)\"
        $report.RDPLogonAuditEnabled = \"未知\"
    }

    # 5. 遠端桌面使用者群組成員
    try {
        $remoteDesktopUsers = Get-LocalGroupMember -Group \"Remote Desktop Users\" -ErrorAction Stop | Select-Object -ExpandProperty Name
        $report.RemoteDesktopUsers = $remoteDesktopUsers
        Write-Log -Message \"\'遠端桌面使用者\' 群組成員：$($remoteDesktopUsers -join \', \')\"
    }
    catch {
        Write-Log -Level Warn -Message \"無法獲取 \'遠端桌面使用者\' 群組成員：$($_.Exception.Message)\"
        $report.RemoteDesktopUsers = \"未知\"
    }

    return $report
}

# -----------------------------------------------------------------------------
# 函數：Set-RDPConfiguration
# 描述：根據指定參數配置 RDP 安全設定。
# 參數：
#   -DisableRDP：是否禁用 RDP 服務。
#   -ForceNLA：是否強制啟用 NLA。
#   -RestrictIP：限制 RDP 存取的 IP 範圍 (例如：\'192.168.1.0/24\', \'10.0.0.1\')。
#   -EnableRDPLog：是否啟用 RDP 連接日誌審計。
#   -RemoveRDPUsers：要從 \'遠端桌面使用者\' 群組中移除的使用者列表。
# -----------------------------------------------------------------------------
function Set-RDPConfiguration {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact=\'High\')]
    param(
        [switch]$DisableRDP,
        [switch]$ForceNLA,
        [string[]]$RestrictIP,
        [switch]$EnableRDPLog,
        [string[]]$RemoveRDPUsers
    )

    $changesMade = $false

    # 1. 禁用 RDP 服務
    if ($PSCmdlet.ShouldProcess(\"RDP 服務\", \"禁用 RDP 服務\")) {
        if ($DisableRDP) {
            try {
                Set-ItemProperty -Path \'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name \'fDenyTSConnections\' -Value 1 -Force -ErrorAction Stop
                Write-Log -Message \"已禁用 RDP 服務。\"
                $changesMade = $true
            }
            catch {
                Write-Log -Level Error -Message \"禁用 RDP 服務失敗：$($_.Exception.Message)\"
            }
        }
    }

    # 2. 強制啟用 NLA
    if ($PSCmdlet.ShouldProcess(\"NLA\", \"強制啟用網路層級驗證 (NLA)\")) {
        if ($ForceNLA) {
            try {
                Set-ItemProperty -Path \'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name \'UserAuthentication\' -Value 1 -Force -ErrorAction Stop
                Write-Log -Message \"已強制啟用 NLA。\"
                $changesMade = $true
            }
            catch {
                Write-Log -Level Error -Message \"強制啟用 NLA 失敗：$($_.Exception.Message)\"
            }
        }
    }

    # 3. 限制 RDP 存取 IP 範圍 (防火牆規則)
    if ($PSCmdlet.ShouldProcess(\"防火牆規則\", \"限制 RDP 存取 IP 範圍到 \'$($RestrictIP -join \', \')\'\")) {
        if ($RestrictIP) {
            try {
                # 移除現有的 \'遠端桌面 (TCP-In)\' 規則，以便重新創建或修改
                Get-NetFirewallRule -DisplayName \"遠端桌面 (TCP-In)\" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -Confirm:$false -ErrorAction SilentlyContinue
                
                # 創建新的防火牆規則
                New-NetFirewallRule -DisplayName \"遠端桌面 (TCP-In)\" -Direction Inbound -LocalPort 3389 -Protocol TCP -Action Allow -RemoteAddress $RestrictIP -Enabled True -ErrorAction Stop
                Write-Log -Message \"已配置防火牆規則，限制 RDP 存取 IP 範圍到 \'$($RestrictIP -join \', \')\'。\"
                $changesMade = $true
            }
            catch {
                Write-Log -Level Error -Message \"配置防火牆規則失敗：$($_.Exception.Message)\"
            }
        }
    }

    # 4. 啟用 RDP 連接日誌審計
    if ($PSCmdlet.ShouldProcess(\"RDP 連接日誌\", \"啟用 RDP 連接日誌審計\")) {
        if ($EnableRDPLog) {
            try {
                auditpol /set /subcategory:\"Remote Desktop Services\" /success:enable /failure:enable | Out-Null
                Write-Log -Message \"已啟用 RDP 連接日誌審計。\"
                $changesMade = $true
            }
            catch {
                Write-Log -Level Error -Message \"啟用 RDP 連接日誌審計失敗：$($_.Exception.Message)\"
            }
        }
    }

    # 5. 移除不必要的遠端桌面使用者
    if ($PSCmdlet.ShouldProcess(\"\'遠端桌面使用者\' 群組\", \"從 \'遠端桌面使用者\' 群組中移除使用者：$($RemoveRDPUsers -join \', \')\'\")) {
        if ($RemoveRDPUsers) {
            foreach ($user in $RemoveRDPUsers) {
                try {
                    Remove-LocalGroupMember -Group \"Remote Desktop Users\" -Member $user -ErrorAction Stop
                    Write-Log -Message \"已從 \'遠端桌面使用者\' 群組中移除使用者 \'$user\'。\"
                    $changesMade = $true
                }
                catch {
                    Write-Log -Level Error -Message \"從 \'遠端桌面使用者\' 群組中移除使用者 \'$user\' 失敗：$($_.Exception.Message)\"
                }
            }
        }
    }

    return $changesMade
}

#endregion

#region 主執行邏輯

Test-AdminPrivileges

Write-Log -Message \"開始執行 RDP 服務安全強化模塊。\"

$initialReport = Get-RDPStatus
Write-Log -Message \"初始 RDP 安全配置報告：\" -Level Info
$initialReport | ConvertTo-Json -Depth 100 | Write-Host

$global:ModuleReport = @{
    ModuleID = \"A2_RDP_Security\"
    ModuleName = \"RDP 服務安全強化模塊\"
    Status = \"未執行\"
    InitialConfiguration = $initialReport
    ChangesApplied = $false
    FinalConfiguration = $null
    RemediationActions = @()
    Errors = @()
}

# 模擬修復操作 (根據實際需求調整參數)
# 這裡僅為範例，實際執行時應根據使用者輸入或預設策略來決定參數

# 範例：強制啟用 NLA，並限制 RDP 存取為本機網路 (192.168.1.0/24)
# 並啟用 RDP 連接日誌審計，移除一個名為 \'Guest\' 的使用者 (如果存在)

$remediationParameters = @{
    ForceNLA = $true
    RestrictIP = @(\"LocalSubnet\") # 這裡可以替換為實際的 IP 範圍，例如 \"192.168.1.0/24\"
    EnableRDPLog = $true
    RemoveRDPUsers = @(\"Guest\") # 替換為需要移除的實際使用者名稱
}

if ($PSCmdlet.ShouldProcess(\"RDP 安全強化\", \"執行 RDP 安全強化操作\")) {
    Write-Log -Message \"正在執行 RDP 安全強化操作...\" -Level Info
    $changesApplied = Set-RDPConfiguration @remediationParameters
    $global:ModuleReport.ChangesApplied = $changesApplied
    if ($changesApplied) {
        Write-Log -Message \"RDP 安全強化操作已完成。\" -Level Info
        $global:ModuleReport.Status = \"已完成\"
    } else {
        Write-Log -Message \"RDP 安全強化操作未進行任何更改。\" -Level Warn
        $global:ModuleReport.Status = \"未更改\"
    }
}
else {
    Write-Log -Message \"使用者取消了 RDP 安全強化操作。\" -Level Warn
    $global:ModuleReport.Status = \"已取消\"
}

$finalReport = Get-RDPStatus
$global:ModuleReport.FinalConfiguration = $finalReport
Write-Log -Message \"最終 RDP 安全配置報告：\" -Level Info
$finalReport | ConvertTo-Json -Depth 100 | Write-Host

# 生成 JSON 格式的檢測報告
$reportPath = \"$PSScriptRoot\\A2_RDP_Security_Report.json\"
$global:ModuleReport | ConvertTo-Json -Depth 100 | Set-Content -Path $reportPath -Encoding UTF8 -Force
Write-Log -Message \"已生成 JSON 格式的檢測報告：$reportPath\" -Level Info

Write-Log -Message \"RDP 服務安全強化模塊執行完畢。\"

#endregion
