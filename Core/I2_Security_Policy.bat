<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>

<#
.SYNOPSIS
    本機安全策略強化模塊 (I2_Security_Policy)

.DESCRIPTION
    此腳本用於強化 Windows 系統的本機安全策略，包括密碼策略、帳戶鎖定策略、審計策略、使用者權限指派和安全選項，以提升系統安全性。
    支援 -WhatIf 和 -Confirm 參數，並提供多級別日誌記錄和進度顯示。

.PARAMETER WhatIf
    顯示執行腳本時會發生的情況，但不實際執行。

.PARAMETER Confirm
    在執行任何操作之前提示您進行確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    編碼：UTF-8 with BOM

.EXAMPLE
    .\[I2_Security_Policy.ps1](http://I2_Security_Policy.ps1) -WhatIf

.EXAMPLE
    .\[I2_Security_Policy.ps1](http://I2_Security_Policy.ps1) -Confirm

.EXAMPLE
    .\[I2_Security_Policy.ps1](http://I2_Security_Policy.ps1)
#>

# 設置 UTF-8 with BOM 編碼
$BOM = New-Object System.Text.UTF8Encoding($True)
[Console]::OutputEncoding = $BOM

# 導入日誌模塊 (假設 Logger.ps1 存在於 Core 目錄)
# 實際部署時需要確保路徑正確或將 Logger.ps1 內容嵌入
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$loggerPath = Join-Path $scriptPath "..\Logger.ps1"
# 如果 Logger.ps1 不存在，則定義一個簡單的日誌函數
if (-not (Test-Path $loggerPath)) {
    function Write-Log {
        Param(
            [Parameter(Mandatory=$true)]
            [string]$Message,
            [string]$Level = "INFO"
        )
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp][$Level] $Message"
    }
} else {
    . $loggerPath
}

# 函數：獲取當前安全策略配置
function Get-SecurityPolicy {
    [CmdletBinding()]
    Param()

    Write-Log -Message "正在獲取當前安全策略配置..." -Level "INFO"
    $policySettings = @{}

    try {
        # 密碼策略
        $policySettings["MinimumPasswordLength"] = (secedit /query /cfg secedit.inf /areas SECURITYPOLICY | Select-String "MinimumPasswordLength").ToString().Split(":")[-1].Trim()
        $policySettings["PasswordComplexity"] = (secedit /query /cfg secedit.inf /areas SECURITYPOLICY | Select-String "PasswordComplexity").ToString().Split(":")[-1].Trim()
        $policySettings["PasswordHistorySize"] = (secedit /query /cfg secedit.inf /areas SECURITYPOLICY | Select-String "PasswordHistorySize").ToString().Split(":")[-1].Trim()
        $policySettings["MaximumPasswordAge"] = (secedit /query /cfg secedit.inf /areas SECURITYPOLICY | Select-String "MaximumPasswordAge").ToString().Split(":")[-1].Trim()
        $policySettings["MinimumPasswordAge"] = (secedit /query /cfg secedit.inf /areas SECURITYPOLICY | Select-String "MinimumPasswordAge").ToString().Split(":")[-1].Trim()

        # 帳戶鎖定策略
        $policySettings["LockoutBadCount"] = (secedit /query /cfg secedit.inf /areas SECURITYPOLICY | Select-String "LockoutBadCount").ToString().Split(":")[-1].Trim()
        $policySettings["ResetLockoutCount"] = (secedit /query /cfg secedit.inf /areas SECURITYPOLICY | Select-String "ResetLockoutCount").ToString().Split(":")[-1].Trim()
        $policySettings["LockoutDuration"] = (secedit /query /cfg secedit.inf /areas SECURITYPOLICY | Select-String "LockoutDuration").ToString().Split(":")[-1].Trim()

        # 審計策略 (需要更詳細的處理，這裡僅為示例)
        $policySettings["AuditSystemEvents"] = (auditpol /get /category:"System" | Select-String "System Events").ToString().Split(":")[-1].Trim()

        Write-Log -Message "成功獲取當前安全策略配置。" -Level "INFO"
    }
    catch {
        Write-Log -Message "獲取安全策略配置時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
    }
    return $policySettings
}

# 函數：應用安全策略
function Apply-SecurityPolicy {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$true)]
        [hashtable]$PolicySettings
    )

    if ($PSCmdlet.ShouldProcess("應用安全策略", "您確定要應用這些安全策略嗎？")) {
        Write-Log -Message "正在應用安全策略..." -Level "INFO"
        $tempInfPath = Join-Path $env:TEMP "secedit_config.inf"
        $tempSifPath = Join-Path $env:TEMP "secedit_config.sif"

        try {
            # 創建一個臨時的 .inf 文件來配置策略
            @"
[Unicode]
Unicode=yes
[Version]
signature="$CHICAGO$"
Revision=1
[System Access]
MinimumPasswordLength = $($PolicySettings["MinimumPasswordLength"])
PasswordComplexity = $($PolicySettings["PasswordComplexity"])
PasswordHistorySize = $($PolicySettings["PasswordHistorySize"])
MaximumPasswordAge = $($PolicySettings["MaximumPasswordAge"])
MinimumPasswordAge = $($PolicySettings["MinimumPasswordAge"])
LockoutBadCount = $($PolicySettings["LockoutBadCount"])
ResetLockoutCount = $($PolicySettings["ResetLockoutCount"])
LockoutDuration = $($PolicySettings["LockoutDuration"])
"@ | Out-File -FilePath $tempInfPath -Encoding UTF8 -Force

            # 應用策略
            Write-Log -Message "正在導入安全策略文件: $tempInfPath" -Level "INFO"
            secedit /configure /db $tempSifPath /cfg $tempInfPath /areas SECURITYPOLICY /overwrite

            # 審計策略 (使用 auditpol)
            Write-Log -Message "正在配置審計策略..." -Level "INFO"
            auditpol /set /category:"System" /success:enable /failure:enable | Out-Null
            auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable | Out-Null
            auditpol /set /category:"Object Access" /success:enable /failure:enable | Out-Null
            auditpol /set /category:"Privilege Use" /success:enable /failure:enable | Out-Null
            auditpol /set /category:"Policy Change" /success:enable /failure:enable | Out-Null

            # 使用者權限指派和安全選項 (需要更複雜的處理，這裡僅為示例)
            # 例如：限制匿名存取、禁用來賓帳戶等
            Write-Log -Message "正在配置使用者權限指派和安全選項..." -Level "INFO"
            # 示例：禁用來賓帳戶
            net user Guest /active:no | Out-Null

            Write-Log -Message "安全策略應用完成。" -Level "INFO"
        }
        catch {
            Write-Log -Message "應用安全策略時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
            return $false
        }
        finally {
            # 清理臨時文件
            if (Test-Path $tempInfPath) { Remove-Item $tempInfPath -Force -ErrorAction SilentlyContinue }
            if (Test-Path $tempSifPath) { Remove-Item $tempSifPath -Force -ErrorAction SilentlyContinue }
        }
        return $true
    }
    return $false
}

# 主執行邏輯
function Invoke-SecurityPolicyHardening {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param()

    Write-Log -Message "開始執行本機安全策略強化模塊 (I2_Security_Policy)。" -Level "INFO"

    $report = @{
        ModuleId = "I2_Security_Policy"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Status = "Failed"
        Details = @{}
    }

    try {
        Write-Progress -Activity "本機安全策略強化" -Status "正在獲取當前策略..." -PercentComplete 10
        $initialPolicy = Get-SecurityPolicy
        $report.Details.InitialPolicy = $initialPolicy

        # 定義要應用的強化策略
        $desiredPolicy = @{
            "MinimumPasswordLength" = 14  # 密碼長度至少 14 個字元
            "PasswordComplexity" = 1      # 啟用密碼複雜性要求
            "PasswordHistorySize" = 24    # 記住 24 個密碼歷史記錄
            "MaximumPasswordAge" = 60     # 密碼最長使用期限 60 天
            "MinimumPasswordAge" = 1      # 密碼最短使用期限 1 天
            "LockoutBadCount" = 5         # 帳戶鎖定閾值 5 次無效登入
            "ResetLockoutCount" = 30      # 重設帳戶鎖定計數器 30 分鐘
            "LockoutDuration" = 30        # 帳戶鎖定持續時間 30 分鐘
        }
        $report.Details.DesiredPolicy = $desiredPolicy

        Write-Progress -Activity "本機安全策略強化" -Status "正在應用強化策略..." -PercentComplete 50
        $applyResult = Apply-SecurityPolicy -PolicySettings $desiredPolicy

        if ($applyResult) {
            Write-Progress -Activity "本機安全策略強化" -Status "正在驗證應用結果..." -PercentComplete 80
            $finalPolicy = Get-SecurityPolicy
            $report.Details.FinalPolicy = $finalPolicy
            $report.Status = "Completed"
            Write-Log -Message "本機安全策略強化模塊執行成功。" -Level "INFO"
        } else {
            Write-Log -Message "本機安全策略強化模塊執行失敗，策略應用未成功。" -Level "ERROR"
            $report.Status = "Failed"
        }
    }
    catch {
        Write-Log -Message "執行本機安全策略強化模塊時發生未預期的錯誤: $($_.Exception.Message)" -Level "CRITICAL"
        $report.Status = "Failed"
        $report.Details.Error = $_.Exception.Message
    }
    finally {
        Write-Progress -Activity "本機安全策略強化" -Status "完成" -PercentComplete 100 -Completed
        # 生成 JSON 報告
        $reportJson = $report | ConvertTo-Json -Depth 100
        $reportFileName = "I2_Security_Policy_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $reportPath = Join-Path (Join-Path $scriptPath "..\..\Reports") $reportFileName
        
        # 確保 Reports 目錄存在
        if (-not (Test-Path (Join-Path $scriptPath "..\..\Reports"))) {
            mkdir (Join-Path $scriptPath "..\..\Reports") | Out-Null
        }

        $reportJson | Out-File -FilePath $reportPath -Encoding UTF8 -Force
        Write-Log -Message "檢測報告已生成: $reportPath" -Level "INFO"
    }
}

# 執行主函數
Invoke-SecurityPolicyHardening @PSBoundParameters
