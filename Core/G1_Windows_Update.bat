<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>

```powershell
<#
.SYNOPSIS
    Windows Update 修復與強制啟用模塊

.DESCRIPTION
    此腳本旨在修復 Windows Update 的常見問題，並強制啟用 Windows Update 服務，確保系統能夠正常接收更新。
    支援 -WhatIf 和 -Confirm 參數，提供多級別日誌記錄和進度顯示。

.PARAMETER WhatIf
    顯示如果執行命令會發生什麼，而不實際執行命令。

.PARAMETER Confirm
    在執行命令前提示您進行確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    編碼：UTF-8 with BOM
#>

#region 參數定義
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param()
#endregion

#region 函數定義
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"
    Write-Host $LogEntry
    # 實際應用中可將日誌寫入文件
}

function Test-AdminPrivileges {
    Write-Log -Message "檢查管理員權限..." -Level "DEBUG"
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log -Message "此腳本需要管理員權限才能運行。請以管理員身份運行。" -Level "ERROR"
        return $false
    }
    Write-Log -Message "已具備管理員權限。" -Level "DEBUG"
    return $true
}

function Stop-WindowsUpdateServices {
    Write-Log -Message "停止相關 Windows Update 服務..." -Level "INFO"
    $servicesToStop = @("wuauserv", "bits", "dosvc", "cryptSvc")
    foreach ($service in $servicesToStop) {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            if ((Get-Service -Name $service).Status -ne 'Stopped') {
                if ($PSCmdlet.ShouldProcess("停止服務 '$service'")) {
                    try {
                        Stop-Service -Name $service -Force -ErrorAction Stop
                        Write-Log -Message "服務 '$service' 已停止。" -Level "INFO"
                    }
                    catch {
                        Write-Log -Message "無法停止服務 '$service'：$($_.Exception.Message)" -Level "ERROR"
                    }
                }
            }
            else {
                Write-Log -Message "服務 '$service' 已停止。" -Level "INFO"
            }
        }
        else {
            Write-Log -Message "服務 '$service' 不存在。" -Level "WARN"
        }
    }
}

function Start-WindowsUpdateServices {
    Write-Log -Message "啟動相關 Windows Update 服務..." -Level "INFO"
    $servicesToStart = @("wuauserv", "bits", "dosvc", "cryptSvc")
    foreach ($service in $servicesToStart) {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            if ((Get-Service -Name $service).Status -ne 'Running') {
                if ($PSCmdlet.ShouldProcess("啟動服務 '$service'")) {
                    try {
                        Start-Service -Name $service -ErrorAction Stop
                        Write-Log -Message "服務 '$service' 已啟動。" -Level "INFO"
                    }
                    catch {
                        Write-Log -Message "無法啟動服務 '$service'：$($_.Exception.Message)" -Level "ERROR"
                    }
                }
            }
            else {
                Write-Log -Message "服務 '$service' 已運行。" -Level "INFO"
            }
        }
        else {
            Write-Log -Message "服務 '$service' 不存在。" -Level "WARN"
        }
    }
}

function Reset-WindowsUpdateComponents {
    Write-Log -Message "重置 Windows Update 組件..." -Level "INFO"
    $commands = @(
        "net stop wuauserv",
        "net stop bits",
        "net stop dosvc",
        "net stop cryptSvc",
        "Ren C:\Windows\SoftwareDistribution SoftwareDistribution.old",
        "Ren C:\Windows\System32\catroot2 catroot2.old",
        "net start wuauserv",
        "net start bits",
        "net start dosvc",
        "net start cryptSvc"
    )

    $progress = 0
    $totalCommands = $commands.Count

    foreach ($cmd in $commands) {
        $progress++
        $status = "執行命令 ($progress/$totalCommands): $cmd"
        Write-Progress -Activity "重置 Windows Update 組件" -Status $status -PercentComplete (($progress / $totalCommands) * 100)

        if ($PSCmdlet.ShouldProcess("執行命令 '$cmd'")) {
            try {
                Write-Log -Message "執行：$cmd" -Level "DEBUG"
                Invoke-Expression $cmd -ErrorAction Stop
                Write-Log -Message "命令 '$cmd' 執行成功。" -Level "INFO"
            }
            catch {
                Write-Log -Message "命令 '$cmd' 執行失敗：$($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
    Write-Progress -Activity "重置 Windows Update 組件" -Status "完成" -PercentComplete 100 -Completed
}

function Repair-WindowsUpdateRegistry {
    Write-Log -Message "修復 Windows Update 相關註冊表項..." -Level "INFO"
    if ($PSCmdlet.ShouldProcess("修復註冊表項")) {
        try {
            # 確保 Windows Update 服務的啟動類型為自動
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\wuauserv" -Name "Start" -Value 2 -Force -ErrorAction Stop
            Write-Log -Message "已將 wuauserv 服務啟動類型設置為自動。" -Level "INFO"

            # 確保 BITS 服務的啟動類型為自動
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\BITS" -Name "Start" -Value 2 -Force -ErrorAction Stop
            Write-Log -Message "已將 BITS 服務啟動類型設置為自動。" -Level "INFO"

            # 確保 DoSVC 服務的啟動類型為自動
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DoSvc" -Name "Start" -Value 2 -Force -ErrorAction Stop
            Write-Log -Message "已將 DoSvc 服務啟動類型設置為自動。" -Level "INFO"

            # 確保 CryptSvc 服務的啟動類型為自動
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CryptSvc" -Name "Start" -Value 2 -Force -ErrorAction Stop
            Write-Log -Message "已將 CryptSvc 服務啟動類型設置為自動。" -Level "INFO"

            Write-Log -Message "Windows Update 相關註冊表項修復完成。" -Level "INFO"
        }
        catch {
            Write-Log -Message "修復 Windows Update 註冊表項失敗：$($_.Exception.Message)" -Level "ERROR"
        }
    }
}

function Generate-DetectionReport {
    Write-Log -Message "生成檢測報告..." -Level "INFO"
    $reportPath = "$PSScriptRoot\G1_Windows_Update_Report.json"
    $report = @{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss");
        Module = "G1_Windows_Update";
        Status = "";
        Details = @();
        Recommendations = @();
    }

    # 檢查 Windows Update 服務狀態
    $wuauserv = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    if ($wuauserv) {
        $report.Details += "Windows Update 服務 (wuauserv) 狀態: $($wuauserv.Status)"
        if ($wuauserv.Status -ne 'Running') {
            $report.Recommendations += "建議啟動 Windows Update 服務 (wuauserv)。"
        }
    } else {
        $report.Details += "Windows Update 服務 (wuauserv) 不存在。"
        $report.Recommendations += "建議檢查 Windows Update 服務是否存在。"
    }

    # 檢查 BITS 服務狀態
    $bits = Get-Service -Name "bits" -ErrorAction SilentlyContinue
    if ($bits) {
        $report.Details += "背景智慧傳輸服務 (BITS) 狀態: $($bits.Status)"
        if ($bits.Status -ne 'Running') {
            $report.Recommendations += "建議啟動背景智慧傳輸服務 (BITS)。"
        }
    } else {
        $report.Details += "背景智慧傳輸服務 (BITS) 不存在。"
        $report.Recommendations += "建議檢查背景智慧傳輸服務是否存在。"
    }

    # 檢查 SoftwareDistribution 資料夾
    if (-not (Test-Path "C:\Windows\SoftwareDistribution")) {
        $report.Details += "SoftwareDistribution 資料夾不存在。"
        $report.Recommendations += "建議重建 SoftwareDistribution 資料夾。"
    }

    # 判斷整體狀態
    if ($report.Recommendations.Count -eq 0) {
        $report.Status = "健康"
    } else {
        $report.Status = "需要注意"
    }

    $report | ConvertTo-Json -Depth 100 | Out-File -FilePath $reportPath -Encoding UTF8 -Force
    Write-Log -Message "檢測報告已生成至：$reportPath" -Level "INFO"
    return $reportPath
}
#endregion

#region 主邏輯
function Main {
    if (-not (Test-AdminPrivileges)) {
        exit 1
    }

    Write-Log -Message "開始執行 G1_Windows_Update 模塊..." -Level "INFO"

    # 停止服務
    Stop-WindowsUpdateServices

    # 重置組件
    Reset-WindowsUpdateComponents

    # 修復註冊表
    Repair-WindowsUpdateRegistry

    # 啟動服務
    Start-WindowsUpdateServices

    # 生成報告
    $reportFile = Generate-DetectionReport

    Write-Log -Message "G1_Windows_Update 模塊執行完成。" -Level "INFO"
    Write-Log -Message "檢測報告路徑：$reportFile" -Level "INFO"
}

Main
#endregion
```
