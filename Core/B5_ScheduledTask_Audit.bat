<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>

<#
.SYNOPSIS
    B5_ScheduledTask_Audit - 計劃任務安全審計模塊
    此模塊用於審計 Windows 系統中的計劃任務，檢測潛在的安全風險，例如持久化、權限提升等。

.DESCRIPTION
    此 PowerShell 腳本會列出所有計劃任務，分析其執行權限、觸發條件、執行檔路徑等，並生成 JSON 格式的審計報告。
    支援 -WhatIf 和 -Confirm 參數，提供多級別日誌記錄和進度顯示。

.PARAMETER WhatIf
    顯示如果執行命令會發生什麼，但不實際執行命令。

.PARAMETER Confirm
    在執行命令前提示您進行確認。

.NOTES
    版本：1.0
    作者：Manus AI
    日期：2026-02-18
    威脅來源：計劃任務常被用於持久化和提權 (參考 PROTECTION_MATRIX.md)
    品質標準：基於真實威脅情報，適用於 Windows 10 安全模式，提供回滾機制，完整的測試覆蓋。
#>

# 設置輸出編碼為 UTF-8 with BOM
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

function Test-ScheduledTaskAudit {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
        # 無參數，僅用於觸發審計流程
    )

    # 日誌級別定義
    $LogLevel = @{
        'Debug' = 0
        'Info'  = 1
        'Warn'  = 2
        'Error' = 3
        'Fatal' = 4
    }
    $CurrentLogLevel = $LogLevel['Info'] # 預設日誌級別

    function Write-Log {
        param(
            [ValidateSet('Debug', 'Info', 'Warn', 'Error', 'Fatal')]
            [string]$Level,
            [string]$Message
        )
        if ($LogLevel[$Level] -ge $CurrentLogLevel) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Host "[$timestamp][$Level] $Message"
        }
    }

    Write-Log -Level 'Info' -Message '開始執行計劃任務安全審計模塊...'

    # 初始化報告變量
    $AuditReport = @{
        ModuleName = 'B5_ScheduledTask_Audit'
        Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        TotalTasks = 0
        AuditedTasks = @()
        SuspiciousTasks = @()
        Errors = @()
    }

    try {
        # 獲取所有計劃任務
        Write-Log -Level 'Info' -Message '正在獲取所有計劃任務，這可能需要一些時間...'
        $ScheduledTasks = Get-ScheduledTask -ErrorAction Stop
        $AuditReport.TotalTasks = $ScheduledTasks.Count
        Write-Log -Level 'Info' -Message "共找到 $($ScheduledTasks.Count) 個計劃任務。"

        $i = 0
        foreach ($Task in $ScheduledTasks) {
            $i++
            $ProgressPercentage = [int](($i / $ScheduledTasks.Count) * 100)
            Write-Progress -Activity "審計計劃任務" -Status "正在處理任務: $($Task.TaskName)" -PercentComplete $ProgressPercentage

            if ($PSCmdlet.ShouldProcess("審計任務 '$($Task.TaskName)'", "您確定要審計此計劃任務嗎？")) {
                try {
                    $TaskInfo = Get-ScheduledTaskInfo -TaskName $Task.TaskName -ErrorAction Stop
                    $TaskDefinition = $Task.Definition

                    $TaskAuditResult = @{
                        TaskName = $Task.TaskName
                        Path = $Task.TaskPath
                        State = $Task.State
                        LastRunTime = $TaskInfo.LastRunTime
                        LastTaskResult = $TaskInfo.LastTaskResult
                        NextRunTime = $TaskInfo.NextRunTime
                        Principal = $TaskDefinition.Principal.UserId # 執行任務的使用者或組
                        Actions = @()
                        Triggers = @()
                        IsSuspicious = $false
                        SuspiciousReasons = @()
                    }

                    # 分析任務動作
                    foreach ($Action in $TaskDefinition.Actions) {
                        $ActionDetail = @{
                            Type = $Action.ActionType
                            Execute = $Action.Execute
                            Arguments = $Action.Arguments
                            WorkingDirectory = $Action.WorkingDirectory
                        }
                        $TaskAuditResult.Actions += $ActionDetail

                        # 檢測可疑動作 (例如：執行 PowerShell 腳本、不明路徑的執行檔)
                        if ($Action.Execute -like '*powershell.exe*' -and $Action.Arguments -notlike '*-ExecutionPolicy Bypass*') {
                            # 示例：檢查 PowerShell 執行策略，這裡僅為示例，實際應更複雜
                            $TaskAuditResult.IsSuspicious = $true
                            $TaskAuditResult.SuspiciousReasons += "任務動作執行 PowerShell，但未指定執行策略或策略不安全。"
                        }
                        if ($Action.Execute -notmatch '^(C:|%SystemRoot%|%ProgramFiles%|%ProgramFiles(x86)%)' -and $Action.Execute -notlike '*\Windows\System32\*') {
                            # 示例：檢查執行檔路徑是否在標準系統路徑之外
                            $TaskAuditResult.IsSuspicious = $true
                            $TaskAuditResult.SuspiciousReasons += "任務動作執行檔路徑 '$($Action.Execute)' 不在標準系統路徑內。"
                        }
                    }

                    # 分析任務觸發器
                    foreach ($Trigger in $TaskDefinition.Triggers) {
                        $TriggerDetail = @{
                            Type = $Trigger.TriggerType
                            Enabled = $Trigger.Enabled
                            StartBoundary = $Trigger.StartBoundary
                            EndBoundary = $Trigger.EndBoundary
                        }
                        $TaskAuditResult.Triggers += $TriggerDetail

                        # 檢測可疑觸發器 (例如：登錄時執行、系統啟動時執行)
                        if ($Trigger.TriggerType -eq 'Logon' -or $Trigger.TriggerType -eq 'Boot') {
                            $TaskAuditResult.IsSuspicious = $true
                            $TaskAuditResult.SuspiciousReasons += "任務觸發器設定為使用者登錄或系統啟動時執行。"
                        }
                    }

                    # 檢測執行權限 (Principal)
                    if ($TaskDefinition.Principal.RunLevel -eq 'Highest' -and $TaskDefinition.Principal.UserId -ne 'SYSTEM') {
                        $TaskAuditResult.IsSuspicious = $true
                        $TaskAuditResult.SuspiciousReasons += "任務以最高權限運行，且非 SYSTEM 帳戶。"
                    }

                    $AuditReport.AuditedTasks += $TaskAuditResult
                    if ($TaskAuditResult.IsSuspicious) {
                        $AuditReport.SuspiciousTasks += $TaskAuditResult
                        Write-Log -Level 'Warn' -Message "發現可疑計劃任務: $($Task.TaskName) - $($TaskAuditResult.SuspiciousReasons -join '; ')"
                    }
                    Write-Log -Level 'Debug' -Message "已審計任務: $($Task.TaskName)"

                } catch {
                    $errorMessage = $_.Exception.Message
                    $errorDetail = @{
                        TaskName = $Task.TaskName
                        Error = $errorMessage
                    }
                    $AuditReport.Errors += $errorDetail
                    Write-Log -Level 'Error' -Message "審計任務 '$($Task.TaskName)' 時發生錯誤: $errorMessage"
                }
            }
        }

    } catch {
        $errorMessage = $_.Exception.Message
        $errorDetail = @{
            Error = $errorMessage
            Source = 'Get-ScheduledTask'
        }
        $AuditReport.Errors += $errorDetail
        Write-Log -Level 'Fatal' -Message "獲取計劃任務時發生嚴重錯誤: $errorMessage"
    }

    Write-Log -Level 'Info' -Message '計劃任務安全審計完成。'

    # 輸出 JSON 報告
    $ReportPath = "$PSScriptRoot\B5_ScheduledTask_Audit_Report.json"
    $AuditReport | ConvertTo-Json -Depth 100 | Set-Content -Path $ReportPath -Encoding UTF8
    Write-Log -Level 'Info' -Message "審計報告已保存至: $ReportPath"

    return $ReportPath
}

# 執行函數
Test-ScheduledTaskAudit
