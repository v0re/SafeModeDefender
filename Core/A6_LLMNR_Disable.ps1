# encoding: utf-8-bom
<#
.SYNOPSIS
    禁用 Windows 系統上的 LLMNR 和 NetBIOS-NS 協議，以增強安全性。

.DESCRIPTION
    此腳本旨在通過修改註冊表和網絡適配器設置來禁用鏈路本地多播名稱解析 (LLMNR) 和 NetBIOS 名稱服務 (NetBIOS-NS)。
    這些協議可能被攻擊者用於名稱解析欺騙攻擊，從而導致憑據洩露和其他安全風險。

.PARAMETER WhatIf
    顯示如果執行命令會發生什麼，而不實際執行它。

.PARAMETER Confirm
    在執行命令之前提示您進行確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    要求：Windows 10 或更高版本，需要管理員權限。
#>

#Requires -RunAsAdministrator

param(
    [switch]$WhatIf,
    [switch]$Confirm
)

#region 函數定義

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO" # INFO, WARN, ERROR, DEBUG
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"
    Write-Host $LogEntry
    # 實際應用中可以將日誌寫入文件
}

function Test-Administrator {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Log -Message "此腳本需要管理員權限才能運行。請以管理員身份運行。" -Level "ERROR"
        return $false
    }
    return $true
}

function Get-NetbiosOverTcpipStatus {
    # 獲取所有網絡適配器的 NetBIOS over TCP/IP 狀態
    $Adapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'TRUE'"
    $Status = @()
    foreach ($Adapter in $Adapters) {
        $NetbiosStatus = switch ($Adapter.TcpipNetbiosOptions) {
            0 { "Default" }
            1 { "Enable NetBIOS over TCP/IP" }
            2 { "Disable NetBIOS over TCP/IP" }
            default { "Unknown" }
        }
        $Status += [pscustomobject]@{ 
            Description = $Adapter.Description;
            NetbiosOptions = $Adapter.TcpipNetbiosOptions;
            Status = $NetbiosStatus
        }
    }
    return $Status
}

#endregion

#region 主邏輯

if (-not (Test-Administrator)) {
    exit 1
}

Write-Log -Message "開始禁用 LLMNR 和 NetBIOS-NS 協議..." -Level "INFO"

#region LLMNR 禁用

Write-Log -Message "正在檢查 LLMNR 狀態..." -Level "INFO"
$LLMNRRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
$LLMNRPropertyName = "EnableMulticast"
$LLMNRCurrentValue = (Get-ItemProperty -Path $LLMNRRegistryPath -Name $LLMNRPropertyName -ErrorAction SilentlyContinue).$LLMNRPropertyName

if ($LLMNRCurrentValue -eq 0) {
    Write-Log -Message "LLMNR 已禁用。" -Level "INFO"
} else {
    Write-Log -Message "LLMNR 當前已啟用。正在禁用..." -Level "WARN"
    if ($PSCmdlet.ShouldProcess("禁用 LLMNR", "您確定要禁用 LLMNR 嗎？")) {
        try {
            Set-ItemProperty -Path $LLMNRRegistryPath -Name $LLMNRPropertyName -Value 0 -Force -ErrorAction Stop -WhatIf:$WhatIfPreference
            Write-Log -Message "LLMNR 已成功禁用。" -Level "INFO"
        } catch {
            Write-Log -Message "禁用 LLMNR 失敗：$($_.Exception.Message)" -Level "ERROR"
        }
    }
}

#endregion

#region NetBIOS-NS 禁用

Write-Log -Message "正在檢查 NetBIOS over TCP/IP 狀態..." -Level "INFO"
$NetbiosStatusBefore = Get-NetbiosOverTcpipStatus
Write-Log -Message "禁用前 NetBIOS over TCP/IP 狀態： $($NetbiosStatusBefore | ConvertTo-Json -Compress)" -Level "DEBUG"

$Adapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'TRUE'"
$NetbiosDisabledCount = 0

foreach ($Adapter in $Adapters) {
    Write-Progress -Activity "禁用 NetBIOS over TCP/IP" -Status "處理網絡適配器：$($Adapter.Description)" -CurrentOperation "禁用 NetBIOS over TCP/IP" -PercentComplete (($NetbiosDisabledCount / $Adapters.Count) * 100)

    if ($Adapter.TcpipNetbiosOptions -ne 2) {
        Write-Log -Message "網絡適配器 $($Adapter.Description) 的 NetBIOS over TCP/IP 當前已啟用。正在禁用..." -Level "WARN"
        if ($PSCmdlet.ShouldProcess("禁用 $($Adapter.Description) 上的 NetBIOS over TCP/IP", "您確定要禁用 $($Adapter.Description) 上的 NetBIOS over TCP/IP 嗎？")) {
            try {
                $Adapter.SetTcpipNetbios(2) | Out-Null # 2 = Disable NetBIOS over TCP/IP
                Write-Log -Message "網絡適配器 $($Adapter.Description) 的 NetBIOS over TCP/IP 已成功禁用。" -Level "INFO"
                $NetbiosDisabledCount++
            } catch {
                Write-Log -Message "禁用網絡適配器 $($Adapter.Description) 上的 NetBIOS over TCP/IP 失敗：$($_.Exception.Message)" -Level "ERROR"
            }
        }
    } else {
        Write-Log -Message "網絡適配器 $($Adapter.Description) 的 NetBIOS over TCP/IP 已禁用。" -Level "INFO"
        $NetbiosDisabledCount++
    }
}

Write-Progress -Activity "禁用 NetBIOS over TCP/IP" -Status "完成" -CurrentOperation "所有網絡適配器已處理" -PercentComplete 100 -Completed

#endregion

Write-Log -Message "正在生成檢測報告..." -Level "INFO"

$LLMNRStatusAfter = if ((Get-ItemProperty -Path $LLMNRRegistryPath -Name $LLMNRPropertyName -ErrorAction SilentlyContinue).$LLMNRPropertyName -eq 0) { "Disabled" } else { "Enabled" }
$NetbiosStatusAfter = Get-NetbiosOverTcpipStatus

$Report = @{
    ModuleId = "A6_LLMNR_Disable"
    Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    LLMNR = @{
        RegistryPath = $LLMNRRegistryPath;
        PropertyName = $LLMNRPropertyName;
        StatusBefore = if ($LLMNRCurrentValue -eq 0) { "Disabled" } else { "Enabled" };
        StatusAfter = $LLMNRStatusAfter
    };
    NetBIOS_NS = @{
        StatusBefore = $NetbiosStatusBefore;
        StatusAfter = $NetbiosStatusAfter
    };
    OverallStatus = if ($LLMNRStatusAfter -eq "Disabled" -and ($NetbiosStatusAfter | Where-Object {$_.NetbiosOptions -ne 2}).Count -eq 0) { "Success" } else { "Partial Success" }
}

$ReportJson = $Report | ConvertTo-Json -Depth 100
Write-Log -Message "檢測報告：$ReportJson" -Level "INFO"

# 將報告保存到文件 (可選)
# $ReportFilePath = "C:\Temp\A6_LLMNR_Disable_Report.json"
# $ReportJson | Set-Content -Path $ReportFilePath -Encoding UTF8
# Write-Log -Message "檢測報告已保存到 $ReportFilePath" -Level "INFO"

Write-Log -Message "LLMNR 和 NetBIOS-NS 禁用協議完成。" -Level "INFO"

#endregion
