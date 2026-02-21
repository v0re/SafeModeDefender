<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>
<#
.SYNOPSIS
    A1_SMB_Security - SMB 服務安全強化模塊
    此腳本旨在強化 Windows 系統的 SMB 服務安全性，防範常見的 SMB 相關攻擊。

.DESCRIPTION
    此 PowerShell 腳本執行一系列 SMB 服務的安全配置，包括禁用 SMBv1、啟用 SMB 簽章、
    配置防火牆規則等。腳本支援 -WhatIf 和 -Confirm 參數，提供多級別日誌記錄和進度顯示，
    並能生成 JSON 格式的檢測報告。

.PARAMETER WhatIf
    顯示如果執行此命令會發生的情況，但不實際執行該命令。

.PARAMETER Confirm
    在執行命令之前提示您進行確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    編碼：UTF-8 with BOM

.EXAMPLE
    A1_SMB_Security -WhatIf
    此命令將顯示腳本將執行的操作，但不會實際修改系統。

.EXAMPLE
    A1_SMB_Security -Confirm
    此命令將在執行每個重要操作前提示用戶確認。

.EXAMPLE
    A1_SMB_Security
    此命令將直接執行 SMB 安全強化操作。
#>

#region 模塊設定
$ModuleName = "A1_SMB_Security"
$LogFilePath = "$env:TEMP\$($ModuleName)_Log.txt"
$ReportFilePath = "$env:TEMP\$($ModuleName)_Report.json"
#endregion

#region 函數定義
Function Write-Log {
    Param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Level = "INFO" # INFO, WARN, ERROR, DEBUG
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogFilePath -Value $LogEntry
    Write-Host $LogEntry
}

Function Test-AdminPrivileges {
    Write-Log -Message "檢查管理員權限..." -Level "DEBUG"
    $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $IsAdmin) {
        Write-Log -Message "需要管理員權限才能執行此腳本。請以管理員身份運行。" -Level "ERROR"
        throw "需要管理員權限"
    }
    Write-Log -Message "已確認管理員權限。" -Level "DEBUG"
}

Function Set-SmbSecuritySetting {
    Param (
        [Parameter(Mandatory=$true)]
        [string]$SettingName,
        [Parameter(Mandatory=$true)]
        [scriptblock]$ActionScript,
        [scriptblock]$RollbackScript = { Write-Log -Message "未提供回滾腳本用於 $SettingName" -Level "WARN" }
    )

    Write-Log -Message "正在處理設定: $SettingName" -Level "INFO"

    if ($PSCmdlet.ShouldProcess("執行 $SettingName 設定", "您確定要執行此操作嗎？")) {
        try {
            & $ActionScript
            Write-Log -Message "$SettingName 設定成功。" -Level "INFO"
            return $true
        }
        catch {
            Write-Log -Message "$SettingName 設定失敗: $($_.Exception.Message)" -Level "ERROR"
            Write-Log -Message "嘗試回滾 $SettingName..." -Level "WARN"
            try {
                & $RollbackScript
                Write-Log -Message "$SettingName 回滾成功。" -Level "INFO"
            }
            catch {
                Write-Log -Message "$SettingName 回滾失敗: $($_.Exception.Message)" -Level "ERROR"
            }
            return $false
        }
    }
    else {
        Write-Log -Message "$SettingName 設定被用戶取消。" -Level "INFO"
        return $false
    }
}
#endregion

#region 主腳本邏輯
[CmdletBinding(SupportsShouldProcess=$true)]
param ()

Test-AdminPrivileges

Write-Log -Message "開始執行 SMB 服務安全強化模塊: $ModuleName" -Level "INFO"

$Report = @{
    ModuleName = $ModuleName
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Status = "進行中"
    Details = @()
}

$TotalSteps = 5 # 預計的步驟總數
$CurrentStep = 0

# 步驟 1: 禁用 SMBv1
$CurrentStep++
Write-Progress -Activity "SMB 安全強化" -Status "禁用 SMBv1" -PercentComplete (($CurrentStep / $TotalSteps) * 100)
Set-SmbSecuritySetting -SettingName "禁用 SMBv1" -ActionScript {
    Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -Value 0 -Force -ErrorAction Stop
} -RollbackScript {
    Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -ErrorAction SilentlyContinue
}

# 步驟 2: 啟用 SMB 簽章 (客戶端和服務器)
$CurrentStep++
Write-Progress -Activity "SMB 安全強化" -Status "啟用 SMB 簽章" -PercentComplete (($CurrentStep / $TotalSteps) * 100)
Set-SmbSecuritySetting -SettingName "啟用 SMB 簽章" -ActionScript {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "RequireSecuritySignature" -Value 1 -Force -ErrorAction Stop
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "RequireSecuritySignature" -Value 1 -Force -ErrorAction Stop
} -RollbackScript {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "RequireSecuritySignature" -Value 0 -Force -ErrorAction Stop
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "RequireSecuritySignature" -Value 0 -Force -ErrorAction Stop
}

# 步驟 3: 禁用 NetBIOS over TCP/IP (如果不需要)
# 注意：此操作可能影響依賴 NetBIOS 的舊應用程序或服務。請謹慎評估。
$CurrentStep++
Write-Progress -Activity "SMB 安全強化" -Status "禁用 NetBIOS over TCP/IP" -PercentComplete (($CurrentStep / $TotalSteps) * 100)
Set-SmbSecuritySetting -SettingName "禁用 NetBIOS over TCP/IP" -ActionScript {
    # 獲取所有網絡適配器並禁用其 NetBIOS over TCP/IP
    Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | ForEach-Object {
        $_.SetTcpipNetbios(2) | Out-Null # 2 = Disable NetBIOS over TCP/IP
    }
} -RollbackScript {
    Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | ForEach-Object {
        $_.SetTcpipNetbios(0) | Out-Null # 0 = Default (Enable NetBIOS over TCP/IP)
    }
}

# 步驟 4: 配置防火牆規則 (阻止入站 SMB 流量，如果不需要文件共享)
$CurrentStep++
Write-Progress -Activity "SMB 安全強化" -Status "配置防火牆規則" -PercentComplete (($CurrentStep / $TotalSteps) * 100)
Set-SmbSecuritySetting -SettingName "配置防火牆規則 (阻止入站 SMB 流量)" -ActionScript {
    # 阻止 TCP 445 (SMB) 和 UDP 137, 138, TCP 139 (NetBIOS) 入站流量
    New-NetFirewallRule -DisplayName "Block Inbound SMB (TCP 445)" -Direction Inbound -Action Block -Protocol TCP -LocalPort 445 -ErrorAction Stop
    New-NetFirewallRule -DisplayName "Block Inbound NetBIOS (UDP 137)" -Direction Inbound -Action Block -Protocol UDP -LocalPort 137 -ErrorAction Stop
    New-NetFirewallRule -DisplayName "Block Inbound NetBIOS (UDP 138)" -Direction Inbound -Action Block -Protocol UDP -LocalPort 138 -ErrorAction Stop
    New-NetFirewallRule -DisplayName "Block Inbound NetBIOS (TCP 139)" -Direction Inbound -Action Block -Protocol TCP -LocalPort 139 -ErrorAction Stop
} -RollbackScript {
    Remove-NetFirewallRule -DisplayName "Block Inbound SMB (TCP 445)" -ErrorAction SilentlyContinue
    Remove-NetFirewallRule -DisplayName "Block Inbound NetBIOS (UDP 137)" -ErrorAction SilentlyContinue
    Remove-NetFirewallRule -DisplayName "Block Inbound NetBIOS (UDP 138)" -ErrorAction SilentlyContinue
    Remove-NetFirewallRule -DisplayName "Block Inbound NetBIOS (TCP 139)" -ErrorAction SilentlyContinue
}

# 步驟 5: 檢測 SMB 服務狀態並生成報告
$CurrentStep++
Write-Progress -Activity "SMB 安全強化" -Status "生成檢測報告" -PercentComplete (($CurrentStep / $TotalSteps) * 100)
Set-SmbSecuritySetting -SettingName "生成檢測報告" -ActionScript {
    $SmbStatus = @{
        SMBv1Enabled = (Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol).State -eq "Enabled"
        SmbSigningRequiredClient = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "RequireSecuritySignature" -ErrorAction SilentlyContinue).RequireSecuritySignature -eq 1
        SmbSigningRequiredServer = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "RequireSecuritySignature" -ErrorAction SilentlyContinue).RequireSecuritySignature -eq 1
        NetBIOSOverTCPDisabled = (Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true -and $_.TcpipNetbiosOptions -eq 2 }).Count -gt 0
        FirewallRulesBlockedSMB = (Get-NetFirewallRule -DisplayName "Block Inbound SMB (TCP 445)" -ErrorAction SilentlyContinue).Enabled -eq $true
    }
    $Report.Details += $SmbStatus
    $Report.Status = "完成"
    $Report | ConvertTo-Json -Depth 100 | Out-File -FilePath $ReportFilePath -Encoding UTF8 -Force
    Write-Log -Message "檢測報告已生成至 $ReportFilePath" -Level "INFO"
} -RollbackScript {
    Remove-Item -Path $ReportFilePath -ErrorAction SilentlyContinue
}

Write-Log -Message "SMB 服務安全強化模塊執行完畢。" -Level "INFO"
#endregion
