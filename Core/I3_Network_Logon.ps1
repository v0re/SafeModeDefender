
<#
.SYNOPSIS
    I3_Network_Logon - 網路登入方式檢查模塊
    此腳本用於檢查 Windows 系統的網路登入方式，識別潛在的安全風險，並生成詳細的檢測報告。

.DESCRIPTION
    此模塊會分析安全事件日誌，特別是登入事件 (Event ID 4624)，以識別不同類型的網路登入活動。
    它還會檢查與網路登入安全相關的系統配置，例如 NTLMv1/LM 兼容性設置和 SMB 訪客登入設置，
    以確保系統遵循安全最佳實踐。腳本支援 -WhatIf 和 -Confirm 參數，提供多級別日誌記錄和進度顯示。

.PARAMETER WhatIf
    顯示如果執行命令會發生什麼，而不實際執行命令。

.PARAMETER Confirm
    在執行命令之前提示您進行確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026年2月18日
    編碼：UTF-8 with BOM
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

function Get-NetworkLogonEvents {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [int]$Days = 7
    )

    if ($PSCmdlet.ShouldProcess("分析過去 $Days 天的網路登入事件", "您確定要分析網路登入事件嗎？")) {
        Write-Log -Message "開始分析網路登入事件..." -Level "INFO"
        $LogonEvents = @()
        try {
            $StartDate = (Get-Date).AddDays(-$Days)
            $Events = Get-WinEvent -LogName Security -FilterXPath "*[System[(EventID=4624 or EventID=4625 or EventID=4634)] and TimeCreated[DateValue >= '$($StartDate.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))']]" -ErrorAction Stop

            $TotalEvents = $Events.Count
            $i = 0

            foreach ($Event in $Events) {
                $i++
                Write-Progress -Activity "分析安全事件日誌" -Status "處理事件 $i/$TotalEvents" -PercentComplete (($i / $TotalEvents) * 100)

                $EventData = [ordered]@{
                    Timestamp = $Event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                    EventID = $Event.Id
                    LogonType = ""
                    AccountName = ""
                    DomainName = ""
                    SourceNetworkAddress = ""
                    Status = ""
                }

                # 提取事件詳細信息
                $EventProperties = $Event.Properties | Select-Object -ExpandProperty Value

                switch ($Event.Id) {
                    4624 { # 成功登入
                        $EventData.LogonType = $EventProperties[8] # Logon Type
                        $EventData.AccountName = $EventProperties[5] # Account Name
                        $EventData.DomainName = $EventProperties[6] # Account Domain
                        $EventData.SourceNetworkAddress = $EventProperties[18] # Source Network Address
                        $EventData.Status = "成功登入"
                    }
                    4625 { # 登入失敗
                        $EventData.LogonType = $EventProperties[8] # Logon Type
                        $EventData.AccountName = $EventProperties[5] # Account Name
                        $EventData.DomainName = $EventProperties[6] # Account Domain
                        $EventData.SourceNetworkAddress = $EventProperties[19] # Source Network Address
                        $EventData.Status = "登入失敗"
                    }
                    4634 { # 登出
                        $EventData.AccountName = $EventProperties[0] # Account Name
                        $EventData.DomainName = $EventProperties[1] # Account Domain
                        $EventData.Status = "登出"
                    }
                }
                $LogonEvents += $EventData
            }
            Write-Log -Message "網路登入事件分析完成。" -Level "INFO"
            return $LogonEvents
        }
        catch {
            Write-Log -Message "分析網路登入事件時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
            return $null
        }
    }
}

function Check-NetworkLogonSecuritySettings {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    if ($PSCmdlet.ShouldProcess("檢查網路登入安全配置", "您確定要檢查網路登入安全配置嗎？")) {
        Write-Log -Message "開始檢查網路登入安全配置..." -Level "INFO"
        $SecurityReport = [ordered]@{}

        # 檢查 NTLMv1/LM 兼容性設置
        Write-Progress -Activity "檢查安全配置" -Status "檢查 NTLMv1/LM 兼容性設置"
        try {
            $LMCompatibilityLevel = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -ErrorAction Stop | Select-Object -ExpandProperty LmCompatibilityLevel
            $SecurityReport."NTLMv1/LM 兼容性級別" = $LMCompatibilityLevel
            if ($LMCompatibilityLevel -lt 3) {
                $SecurityReport."NTLMv1/LM 兼容性建議" = "警告：NTLMv1/LM 兼容性級別設置過低 ($LMCompatibilityLevel)。建議設置為 3 或更高以禁用 NTLMv1/LM。" -Level "WARN"
            } else {
                $SecurityReport."NTLMv1/LM 兼容性建議" = "NTLMv1/LM 兼容性級別設置安全 ($LMCompatibilityLevel)。" -Level "INFO"
            }
        }
        catch {
            $SecurityReport."NTLMv1/LM 兼容性級別" = "無法讀取或設置不存在"
            $SecurityReport."NTLMv1/LM 兼容性建議" = "錯誤：無法檢查 NTLMv1/LM 兼容性級別: $($_.Exception.Message)" -Level "ERROR"
        }

        # 檢查 SMB 訪客登入設置
        Write-Progress -Activity "檢查安全配置" -Status "檢查 SMB 訪客登入設置"
        try {
            $AllowInsecureGuestAuth = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "AllowInsecureGuestAuth" -ErrorAction Stop | Select-Object -ExpandProperty AllowInsecureGuestAuth
            $SecurityReport."SMB 訪客登入" = $AllowInsecureGuestAuth
            if ($AllowInsecureGuestAuth -eq 1) {
                $SecurityReport."SMB 訪客登入建議" = "警告：允許不安全的 SMB 訪客登入。建議禁用以增強安全性。" -Level "WARN"
            } else {
                $SecurityReport."SMB 訪客登入建議" = "SMB 訪客登入設置安全。" -Level "INFO"
            }
        }
        catch {
            $SecurityReport."SMB 訪客登入" = "無法讀取或設置不存在"
            $SecurityReport."SMB 訪客登入建議" = "錯誤：無法檢查 SMB 訪客登入設置: $($_.Exception.Message)" -Level "ERROR"
        }

        Write-Log -Message "網路登入安全配置檢查完成。" -Level "INFO"
        return $SecurityReport
    }
}

#endregion

#region 主執行邏輯

function Main {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    if ($PSCmdlet.ShouldProcess("執行網路登入方式檢查模塊", "您確定要執行網路登入方式檢查模塊嗎？")) {
        Write-Log -Message "I3_Network_Logon 模塊開始執行..." -Level "INFO"
        $OverallReport = [ordered]@{}

        try {
            # 獲取網路登入事件
            $LogonEvents = Get-NetworkLogonEvents -Days 30 # 預設檢查過去30天的事件
            if ($LogonEvents) {
                $OverallReport."網路登入事件分析" = $LogonEvents
            }

            # 檢查網路登入安全配置
            $SecuritySettings = Check-NetworkLogonSecuritySettings
            if ($SecuritySettings) {
                $OverallReport."網路登入安全配置檢查" = $SecuritySettings
            }

            # 生成 JSON 報告
            $ReportJson = $OverallReport | ConvertTo-Json -Depth 100 -Compress
            $OutputPath = Join-Path $PSScriptRoot "I3_Network_Logon_Report.json"
            $ReportJson | Set-Content -Path $OutputPath -Encoding UTF8 -Force

            Write-Log -Message "檢測報告已生成至：$OutputPath" -Level "INFO"
            Write-Host "報告內容預覽："
            Write-Host $ReportJson

        }
        catch {
            Write-Log -Message "執行模塊時發生未預期的錯誤: $($_.Exception.Message)" -Level "ERROR"
        }
        finally {
            Write-Log -Message "I3_Network_Logon 模塊執行完成。" -Level "INFO"
        }
    }
}

# 執行主函數
Main

#endregion
