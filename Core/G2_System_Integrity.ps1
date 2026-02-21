
```powershell
<#
.SYNOPSIS
    G2_System_Integrity - 系統檔案完整性檢查模塊

.DESCRIPTION
    此 PowerShell 腳本用於檢查 Windows 系統檔案的完整性，並可選擇修復損壞的檔案。
    它支援 -WhatIf 和 -Confirm 參數，提供多級別日誌記錄和進度顯示，並生成 JSON 格式的檢測報告。

.PARAMETER WhatIf
    如果指定此參數，腳本將顯示它將執行的操作，但不會實際執行這些操作。

.PARAMETER Confirm
    如果指定此參數，腳本將在執行任何可能更改系統的操作之前提示確認。

.EXAMPLE
    檢查系統檔案完整性並生成報告：
    PS> .\G2_System_Integrity.ps1

.EXAMPLE
    檢查系統檔案完整性，並在執行修復前提示確認：
    PS> .\G2_System_Integrity.ps1 -Confirm

.EXAMPLE
    預覽將執行的操作，但不實際執行：
    PS> .\G2_System_Integrity.ps1 -WhatIf

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    編碼：UTF-8 with BOM
#>

#region 腳本配置

$OutputEncoding = [System.Text.Encoding]::GetEncoding("utf-8")
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 設置日誌文件路徑
$LogFilePath = Join-Path $PSScriptRoot "G2_System_Integrity_$(Get-Date -Format "yyyyMMdd_HHmmss").log"
$ReportFilePath = Join-Path $PSScriptRoot "G2_System_Integrity_Report_$(Get-Date -Format "yyyyMMdd_HHmmss").json"

# 定義日誌級別
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

#endregion

#region 參數定義

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact=\'High\')]
param()

#endregion

#region 主要邏輯

Function Test-SystemFileIntegrity {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact=\'High\')]
    param()

    Write-Log -Message "開始執行系統檔案完整性檢查..." -Level "INFO"
    $Report = @{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Status = "進行中"
        Details = @()
    }

    try {
        # 檢查是否以管理員權限運行
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Log -Message "此腳本需要管理員權限才能運行。請以管理員身份重新啟動。" -Level "ERROR"
            $Report.Status = "失敗 - 需要管理員權限"
            $Report.Details += @{ Type = "錯誤"; Message = "需要管理員權限" }
            return $Report
        }

        # 執行 SFC /SCANNOW
        Write-Log -Message "執行 SFC /SCANNOW 命令..." -Level "INFO"
        $sfcProcess = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow
        $sfcExitCode = $sfcProcess.ExitCode

        if ($sfcExitCode -eq 0) {
            Write-Log -Message "SFC /SCANNOW 命令執行成功，沒有發現完整性違規。" -Level "INFO"
            $Report.Status = "成功 - 無完整性違規"
            $Report.Details += @{ Type = "資訊"; Message = "SFC /SCANNOW 執行成功，沒有發現完整性違規" }
        } elseif ($sfcExitCode -eq 1) {
            Write-Log -Message "SFC /SCANNOW 命令執行成功，發現並修復了完整性違規。" -Level "WARN"
            $Report.Status = "成功 - 已修復完整性違規"
            $Report.Details += @{ Type = "警告"; Message = "SFC /SCANNOW 執行成功，發現並修復了完整性違規" }
        } else {
            Write-Log -Message "SFC /SCANNOW 命令執行失敗，退出碼：$sfcExitCode。" -Level "ERROR"
            $Report.Status = "失敗 - SFC 執行錯誤"
            $Report.Details += @{ Type = "錯誤"; Message = "SFC /SCANNOW 執行失敗，退出碼：$sfcExitCode" }
        }

        # 檢查 DISM 狀態 (可選，提供更詳細的系統健康狀況)
        Write-Log -Message "執行 DISM /Online /Cleanup-Image /CheckHealth 命令..." -Level "INFO"
        $dismCheckHealthOutput = (Invoke-Expression "dism /Online /Cleanup-Image /CheckHealth") -join "`n"
        Write-Log -Message "DISM CheckHealth 輸出：`n$dismCheckHealthOutput" -Level "DEBUG"
        $Report.Details += @{ Type = "資訊"; Message = "DISM CheckHealth 輸出", Output = $dismCheckHealthOutput }

        if ($dismCheckHealthOutput -match "No component store corruption detected") {
            Write-Log -Message "DISM 檢查健康狀況：沒有發現組件存儲損壞。" -Level "INFO"
        } elseif ($dismCheckHealthOutput -match "The component store is repairable") {
            Write-Log -Message "DISM 檢查健康狀況：發現組件存儲可修復損壞。" -Level "WARN"
            if ($PSCmdlet.ShouldProcess("修復組件存儲", "執行 DISM /Online /Cleanup-Image /RestoreHealth 命令？")) {
                Write-Log -Message "執行 DISM /Online /Cleanup-Image /RestoreHealth 命令..." -Level "INFO"
                $dismRestoreHealthOutput = (Invoke-Expression "dism /Online /Cleanup-Image /RestoreHealth") -join "`n"
                Write-Log -Message "DISM RestoreHealth 輸出：`n$dismRestoreHealthOutput" -Level "DEBUG"
                $Report.Details += @{ Type = "資訊"; Message = "DISM RestoreHealth 輸出", Output = $dismRestoreHealthOutput }
                if ($LASTEXITCODE -eq 0) {
                    Write-Log -Message "DISM /RestoreHealth 命令執行成功。" -Level "INFO"
                    $Report.Status = "成功 - 已修復組件存儲"
                } else {
                    Write-Log -Message "DISM /RestoreHealth 命令執行失敗，退出碼：$LASTEXITCODE。" -Level "ERROR"
                    $Report.Status = "失敗 - DISM 修復錯誤"
                    $Report.Details += @{ Type = "錯誤"; Message = "DISM /RestoreHealth 執行失敗，退出碼：$LASTEXITCODE" }
                }
            } else {
                Write-Log -Message "使用者取消了 DISM 組件存儲修復操作。" -Level "INFO"
                $Report.Details += @{ Type = "資訊"; Message = "使用者取消了 DISM 組件存儲修復" }
            }
        } else {
            Write-Log -Message "DISM 檢查健康狀況：發現未知問題或無法確定狀態。" -Level "ERROR"
            $Report.Status = "失敗 - DISM 未知錯誤"
            $Report.Details += @{ Type = "錯誤"; Message = "DISM 檢查健康狀況發現未知問題" }
        }

    } catch {
        Write-Log -Message "執行系統檔案完整性檢查時發生錯誤：$($_.Exception.Message)" -Level "ERROR"
        $Report.Status = "失敗 - 腳本錯誤"
        $Report.Details += @{ Type = "錯誤"; Message = $_.Exception.Message; StackTrace = $_.ScriptStackTrace }
    }

    Write-Log -Message "系統檔案完整性檢查完成。" -Level "INFO"
    return $Report
}

# 執行主函數
if ($PSCmdlet.ShouldProcess("執行系統檔案完整性檢查", "您確定要執行系統檔案完整性檢查嗎？")) {
    $FinalReport = Test-SystemFileIntegrity
    $FinalReportJson = $FinalReport | ConvertTo-Json -Depth 100
    $FinalReportJson | Out-File -FilePath $ReportFilePath -Encoding UTF8 -Force
    Write-Log -Message "檢測報告已保存至：$ReportFilePath" -Level "INFO"
}

#endregion
```
