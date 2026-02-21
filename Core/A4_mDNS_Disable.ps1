
```powershell
<#
.SYNOPSIS
    禁用 mDNS/Bonjour 服務以增強 Windows 系統安全性。

.DESCRIPTION
    此 PowerShell 腳本旨在禁用 Windows 系統上的 mDNS (Multicast DNS) 和 Bonjour 服務。
    這些服務有時會被惡意軟體利用進行網路偵察或繞過防火牆規則。
    禁用這些服務有助於減少潛在的攻擊面，特別是在安全模式下運行時。

.PARAMETER WhatIf
    顯示如果執行命令會發生什麼，但不實際執行。

.PARAMETER Confirm
    在執行命令之前提示您進行確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026年2月18日
    適用於：Windows 10 及更高版本
    編碼：UTF-8 with BOM
#>

#region 函數定義

function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"
    Write-Host $LogEntry
    # 實際應用中可以將日誌寫入文件
}

function Get-ServiceStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServiceName
    )
    try {
        $Service = Get-Service -Name $ServiceName -ErrorAction Stop
        return $Service.Status
    }
    catch {
        Write-Log -Message "無法獲取服務 '$ServiceName' 的狀態: $($_.Exception.Message)" -Level 'ERROR'
        return "NotFound"
    }
}

function Disable-BonjourService {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [string]$ServiceName = 'Bonjour Service'
    )

    if ($PSCmdlet.ShouldProcess("禁用服務 '$ServiceName'", "您確定要禁用 '$ServiceName' 服務嗎？")) {
        try {
            Write-Log -Message "嘗試禁用服務 '$ServiceName'。"
            Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction Stop
            Stop-Service -Name $ServiceName -ErrorAction SilentlyContinue
            Write-Log -Message "服務 '$ServiceName' 已成功禁用並停止。" -Level 'INFO'
            return $true
        }
        catch {
            Write-Log -Message "禁用服務 '$ServiceName' 失敗: $($_.Exception.Message)" -Level 'ERROR'
            return $false
        }
    }
    return $false
}

function Generate-DetectionReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$ReportData
    )
    $ReportJson = $ReportData | ConvertTo-Json -Depth 100
    $ReportPath = "$PSScriptRoot\A4_mDNS_Disable_Report.json"
    try {
        $ReportJson | Out-File -FilePath $ReportPath -Encoding UTF8 -Force
        Write-Log -Message "檢測報告已生成到: $ReportPath" -Level 'INFO'
        return $ReportPath
    }
    catch {
        Write-Log -Message "生成檢測報告失敗: $($_.Exception.Message)" -Level 'ERROR'
        return $null
    }
}

#endregion

#region 主邏輯

$Report = @{
    ModuleName = "A4_mDNS_Disable"
    Description = "mDNS/Bonjour 服務禁用模塊"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Status = "Initialized"
    ServicesAffected = @()
    ActionsPerformed = @()
    Errors = @()
}

Write-Log -Message "開始執行 A4_mDNS_Disable 模塊。" -Level 'INFO'

$servicesToDisable = @("Bonjour Service", "mDNSResponder") # 根據實際情況添加其他相關服務名稱

$progressCount = 0
$totalServices = $servicesToDisable.Count

foreach ($serviceName in $servicesToDisable) {
    $progressCount++
    Write-Progress -Activity "禁用 mDNS/Bonjour 服務" -Status "正在處理服務: $serviceName" -PercentComplete (($progressCount / $totalServices) * 100)

    Write-Log -Message "檢查服務 '$serviceName'。"
    $initialStatus = Get-ServiceStatus -ServiceName $serviceName
    $Report.ServicesAffected += @{ Name = $serviceName; InitialStatus = $initialStatus; FinalStatus = $initialStatus }

    if ($initialStatus -ne "NotFound") {
        if ($initialStatus -ne "Disabled") {
            Write-Log -Message "服務 '$serviceName' 當前狀態為 '$initialStatus'，嘗試禁用。"
            if (Disable-BonjourService -ServiceName $serviceName) {
                $finalStatus = Get-ServiceStatus -ServiceName $serviceName
                $Report.ServicesAffected[-1].FinalStatus = $finalStatus
                $Report.ActionsPerformed += "服務 '$serviceName' 已從 '$initialStatus' 禁用為 '$finalStatus'。"
            } else {
                $Report.Errors += "未能禁用服務 '$serviceName'。"
            }
        } else {
            Write-Log -Message "服務 '$serviceName' 已禁用，無需操作。" -Level 'INFO'
            $Report.ActionsPerformed += "服務 '$serviceName' 已禁用。"
        }
    } else {
        Write-Log -Message "服務 '$serviceName' 未找到，跳過。" -Level 'WARN'
        $Report.Errors += "服務 '$serviceName' 未找到。"
    }
}

# 處理可能正在運行的 mDNSResponder.exe 進程
Write-Log -Message "檢查並終止 mDNSResponder.exe 進程 (如果存在)。" -Level 'INFO'
try {
    $mDNSProcess = Get-Process -Name "mDNSResponder" -ErrorAction SilentlyContinue
    if ($mDNSProcess) {
        if ($PSCmdlet.ShouldProcess("終止 mDNSResponder.exe 進程", "您確定要終止 mDNSResponder.exe 進程嗎？")) {
            Stop-Process -InputObject $mDNSProcess -Force -ErrorAction Stop
            Write-Log -Message "mDNSResponder.exe 進程已成功終止。" -Level 'INFO'
            $Report.ActionsPerformed += "mDNSResponder.exe 進程已終止。"
        }
    } else {
        Write-Log -Message "未找到 mDNSResponder.exe 進程。" -Level 'INFO'
    }
}
catch {
    Write-Log -Message "終止 mDNSResponder.exe 進程失敗: $($_.Exception.Message)" -Level 'ERROR'
    $Report.Errors += "終止 mDNSResponder.exe 進程失敗。"
}

$Report.Status = if ($Report.Errors.Count -eq 0) { "CompletedSuccessfully" } else { "CompletedWithErrors" }
Generate-DetectionReport -ReportData $Report

Write-Log -Message "A4_mDNS_Disable 模塊執行完成。" -Level 'INFO'

#endregion
```
