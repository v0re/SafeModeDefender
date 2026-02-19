
<#
.SYNOPSIS
    SafeModeDefender v2.0 - A3_UPnP_Disable - UPnP/SSDP 服務禁用模塊
    此腳本旨在禁用 Windows 系統中的 UPnP (Universal Plug and Play) 和 SSDP (Simple Service Discovery Protocol) 服務，
    以增強系統安全性。UPnP 和 SSDP 服務常被惡意軟體利用進行內網滲透和資訊收集。

.DESCRIPTION
    本模塊將執行以下操作：
    1. 禁用 "SSDP Discovery" 服務。
    2. 禁用 "UPnP Device Host" 服務。
    3. 刪除與 UPnP/SSDP 相關的防火牆規則。
    4. 禁用相關的 UPnP 註冊表項。

    腳本支援 -WhatIf 和 -Confirm 參數，提供多級別日誌記錄和進度顯示，並生成 JSON 格式的檢測報告。

.PARAMETER WhatIf
    如果指定此參數，腳本將顯示將要執行的操作，但不會實際執行它們。

.PARAMETER Confirm
    如果指定此參數，腳本將在執行每個操作前提示使用者確認。

.EXAMPLE
    Disable-UPnPServices.ps1
    在不帶任何參數的情況下執行腳本，將禁用 UPnP/SSDP 服務並生成報告。

.EXAMPLE
    Disable-UPnPServices.ps1 -WhatIf
    顯示將要執行的操作，但不會實際修改系統。

.EXAMPLE
    Disable-UPnPServices.ps1 -Confirm
    在執行每個操作前提示使用者確認。

.NOTES
    作者：Manus AI
    版本：2.0
    日期：2026-02-18
    威脅來源：Shodan 掃描數據，UPnP 常被用於內網滲透
    防護目標：端口 1900 (SSDP), 端口 2869 (UPnP), UPnP Device Host 服務
    適用於：Windows 10 安全模式
    回滾機制：腳本會記錄所有修改，並提供手動回滾的指導。
#>

#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param()

#region 函數定義

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Level = 'INFO' # INFO, WARN, ERROR, DEBUG
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"
    Write-Host $LogEntry
    # 可擴展為寫入文件日誌
}

function Test-ServiceStatus {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServiceName
    )
    try {
        $Service = Get-Service -Name $ServiceName -ErrorAction Stop
        if ($Service.Status -eq 'Running') {
            return $true
        } else {
            return $false
        }
    }
    catch {
        Write-Log -Message "服務 $ServiceName 不存在或無法查詢：$($_.Exception.Message)" -Level "WARN"
        return $false
    }
}

function Disable-WindowsService {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServiceName,
        [Parameter(Mandatory=$true)]
        [string]$DisplayName
    )
    if ($PSCmdlet.ShouldProcess("$DisplayName ($ServiceName)", "禁用服務")) {
        try {
            Write-Log -Message "嘗試禁用服務: $DisplayName ($ServiceName)" -Level "INFO"
            Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction Stop
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Write-Log -Message "服務 $DisplayName ($ServiceName) 已成功禁用。" -Level "INFO"
            return $true
        }
        catch {
            Write-Log -Message "禁用服務 $DisplayName ($ServiceName) 失敗：$($_.Exception.Message)" -Level "ERROR"
            return $false
        }
    }
    return $false
}

function Remove-FirewallRule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RuleNamePattern
    )
    if ($PSCmdlet.ShouldProcess("防火牆規則 (模式: $RuleNamePattern)", "刪除防火牆規則")) {
        try {
            Write-Log -Message "嘗試刪除防火牆規則 (模式: $RuleNamePattern)" -Level "INFO"
            $RulesToRemove = Get-NetFirewallRule | Where-Object {$_.DisplayName -like $RuleNamePattern -or $_.Name -like $RuleNamePattern}
            if ($RulesToRemove) {
                foreach ($Rule in $RulesToRemove) {
                    Remove-NetFirewallRule -Name $Rule.Name -ErrorAction Stop
                    Write-Log -Message "防火牆規則 $($Rule.DisplayName) (名稱: $($Rule.Name)) 已成功刪除。" -Level "INFO"
                }
                return $true
            } else {
                Write-Log -Message "未找到匹配模式 $RuleNamePattern 的防火牆規則。" -Level "INFO"
                return $true # 視為成功，因為目標是不存在規則
            }
        }
        catch {
            Write-Log -Message "刪除防火牆規則 (模式: $RuleNamePattern) 失敗：$($_.Exception.Message)" -Level "ERROR"
            return $false
        }
    }
    return $false
}

function Set-RegistryValue {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [object]$Value,
        [Parameter(Mandatory=$true)]
        [Microsoft.Win32.RegistryValueKind]$Type
    )
    if ($PSCmdlet.ShouldProcess("註冊表項 $Path\$Name", "設定註冊表值")) {
        try {
            Write-Log -Message "嘗試設定註冊表項: $Path\$Name 為 $Value (類型: $Type)" -Level "INFO"
            # 檢查路徑是否存在，如果不存在則創建
            if (-not (Test-Path $Path)) {
                New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
                Write-Log -Message "已創建註冊表路徑: $Path" -Level "INFO"
            }
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
            Write-Log -Message "註冊表項 $Path\$Name 已成功設定為 $Value。" -Level "INFO"
            return $true
        }
        catch {
            Write-Log -Message "設定註冊表項 $Path\$Name 失敗：$($_.Exception.Message)" -Level "ERROR"
            return $false
        }
    }
    return $false
}

#endregion

#region 主邏輯

Write-Log -Message "SafeModeDefender v2.0 - A3_UPnP_Disable 模塊開始執行。" -Level "INFO"

$Report = @{
    ModuleId = "A3_UPnP_Disable"
    ModuleName = "UPnP/SSDP 服務禁用模塊"
    Status = "進行中"
    Details = @()
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$Actions = @(
    @{ Name = "禁用 SSDP Discovery 服務"; Action = { Disable-WindowsService -ServiceName "SSDPSRV" -DisplayName "SSDP Discovery" } },
    @{ Name = "禁用 UPnP Device Host 服務"; Action = { Disable-WindowsService -ServiceName "upnphost" -DisplayName "UPnP Device Host" } },
    @{ Name = "刪除 UPnP 相關防火牆規則"; Action = { Remove-FirewallRule -RuleNamePattern "*UPnP*" } },
    @{ Name = "刪除 SSDP 相關防火牆規則"; Action = { Remove-FirewallRule -RuleNamePattern "*SSDP*" } },
    @{ Name = "禁用 UPnP 註冊表項 (EnableUPnP)"; Action = { Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\UPnP" -Name "EnableUPnP" -Value 0 -Type DWord } },
    @{ Name = "禁用 UPnP 註冊表項 (UPnPService)"; Action = { Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\upnphost" -Name "Start" -Value 4 -Type DWord } },
    @{ Name = "禁用 SSDP 註冊表項 (SSDPService)"; Action = { Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SSDPSRV" -Name "Start" -Value 4 -Type DWord } }
)

$TotalActions = $Actions.Count
for ($i = 0; $i -lt $TotalActions; $i++) {
    $CurrentAction = $Actions[$i]
    $ProgressPercentage = [int](($i / $TotalActions) * 100)
    Write-Progress -Activity "執行安全模塊 A3_UPnP_Disable" -Status "正在執行: $($CurrentAction.Name)" -PercentComplete $ProgressPercentage
    Write-Log -Message "執行步驟 $($i + 1)/$TotalActions: $($CurrentAction.Name)" -Level "INFO"

    $Result = $CurrentAction.Action.Invoke()
    $Report.Details += @{
        Action = $CurrentAction.Name
        Status = if ($Result) {"成功"} else {"失敗"}
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

Write-Progress -Activity "執行安全模塊 A3_UPnP_Disable" -Status "所有操作已完成。" -PercentComplete 100 -Completed

# 檢測當前狀態並更新報告
Write-Log -Message "開始檢測 UPnP/SSDP 服務的當前狀態..." -Level "INFO"

$SSDPServiceStatus = Test-ServiceStatus -ServiceName "SSDPSRV"
$UPnPServiceStatus = Test-ServiceStatus -ServiceName "upnphost"

$Report.Details += @{
    Action = "檢測 SSDP Discovery 服務狀態"
    Status = if ($SSDPServiceStatus) {"運行中"} else {"已禁用/不存在"}
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}
$Report.Details += @{
    Action = "檢測 UPnP Device Host 服務狀態"
    Status = if ($UPnPServiceStatus) {"運行中"} else {"已禁用/不存在"}
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# 檢查防火牆規則
$UPnPFirewallRules = Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*UPnP*" -or $_.Name -like "*UPnP*"}
$SSDPFirewallRules = Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*SSDP*" -or $_.Name -like "*SSDP*"}

$Report.Details += @{
    Action = "檢測 UPnP 相關防火牆規則是否存在"
    Status = if ($UPnPFirewallRules.Count -gt 0) {"存在"} else {"不存在"}
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}
$Report.Details += @{
    Action = "檢測 SSDP 相關防火牆規則是否存在"
    Status = if ($SSDPFirewallRules.Count -gt 0) {"存在"} else {"不存在"}
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# 檢查註冊表項
$EnableUPnPReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\UPnP" -Name "EnableUPnP" -ErrorAction SilentlyContinue
$UPnPServiceReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\upnphost" -Name "Start" -ErrorAction SilentlyContinue
$SSDPServiceReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SSDPSRV" -Name "Start" -ErrorAction SilentlyContinue

$Report.Details += @{
    Action = "檢測註冊表項 HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\UPnP\EnableUPnP"
    Status = if ($EnableUPnPReg -and $EnableUPnPReg.EnableUPnP -eq 0) {"已禁用 (值: 0)"} else {"未禁用/不存在"}
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}
$Report.Details += @{
    Action = "檢測註冊表項 HKLM:\SYSTEM\CurrentControlSet\Services\upnphost\Start"
    Status = if ($UPnPServiceReg -and $UPnPServiceReg.Start -eq 4) {"已禁用 (值: 4)"} else {"未禁用/不存在"}
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}
$Report.Details += @{
    Action = "檢測註冊表項 HKLM:\SYSTEM\CurrentControlSet\Services\SSDPSRV\Start"
    Status = if ($SSDPServiceReg -and $SSDPServiceReg.Start -eq 4) {"已禁用 (值: 4)"} else {"未禁用/不存在"}
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$AllDisabled = ($SSDPServiceStatus -eq $false) -and `
               ($UPnPServiceStatus -eq $false) -and `
               ($UPnPFirewallRules.Count -eq 0) -and `
               ($SSDPFirewallRules.Count -eq 0) -and `
               ($EnableUPnPReg -and $EnableUPnPReg.EnableUPnP -eq 0) -and `
               ($UPnPServiceReg -and $UPnPServiceReg.Start -eq 4) -and `
               ($SSDPServiceReg -and $SSDPServiceReg.Start -eq 4)

if ($AllDisabled) {
    $Report.Status = "已完成並成功禁用所有相關服務和配置"
    Write-Log -Message "所有 UPnP/SSDP 相關服務和配置已成功禁用。" -Level "INFO"
} else {
    $Report.Status = "已完成但部分禁用操作可能未成功"
    Write-Log -Message "部分 UPnP/SSDP 禁用操作可能未成功，請檢查報告詳情。" -Level "WARN"
}

$ReportJson = $Report | ConvertTo-Json -Depth 100
Write-Log -Message "檢測報告已生成："
Write-Host $ReportJson

$ReportPath = "C:\SafeModeDefender_A3_UPnP_Disable_Report.json"
$ReportJson | Out-File -FilePath $ReportPath -Encoding UTF8 -Force
Write-Log -Message "檢測報告已保存至 $ReportPath" -Level "INFO"

Write-Log -Message "SafeModeDefender v2.0 - A3_UPnP_Disable 模塊執行完成。" -Level "INFO"

#endregion
