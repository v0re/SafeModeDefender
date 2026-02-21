# encoding: utf-8
<#
.SYNOPSIS
    B1_UAC_Hardening - UAC 強化與繞過防護模塊

.DESCRIPTION
    此腳本旨在強化 Windows 使用者帳戶控制 (UAC) 設定，並提供針對常見 UAC 繞過技術的防護。
    它將檢查當前的 UAC 配置，並建議或應用最佳實踐以提高系統安全性。

.PARAMETER WhatIf
    描述當執行命令時會發生什麼，但實際上不執行命令。

.PARAMETER Confirm
    提示您在執行命令之前進行確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    參考資料：
        - Microsoft Learn: User Account Control overview
        - HackTricks: UAC - User Account Control
        - CVE-2026-21519 (Type Confusion in Desktop Window Manager for Privilege Elevation)
#>

# 設置 PowerShell 腳本的執行策略，確保安全運行
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region 函數定義

Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO','WARN','ERROR','DEBUG')] # 定義日誌級別
        [string]$Level = 'INFO'
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"
    Write-Host $LogEntry
    # 實際應用中可以將日誌寫入文件
}

Function Get-UACStatus {
    [CmdletBinding()]
    Param()
    Write-Log -Message "正在檢測 UAC 配置..." -Level "INFO"
    $UACSettings = @{}
    try {
        $EnableLUA = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction Stop).EnableLUA
        $ConsentPromptBehaviorAdmin = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -ErrorAction Stop).ConsentPromptBehaviorAdmin
        $LocalAccountTokenFilterPolicy = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -ErrorAction Stop).LocalAccountTokenFilterPolicy
        $FilterAdministratorToken = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "FilterAdministratorToken" -ErrorAction Stop).FilterAdministratorToken

        $UACSettings.Add("EnableLUA", $EnableLUA)
        $UACSettings.Add("ConsentPromptBehaviorAdmin", $ConsentPromptBehaviorAdmin)
        $UACSettings.Add("LocalAccountTokenFilterPolicy", $LocalAccountTokenFilterPolicy)
        $UACSettings.Add("FilterAdministratorToken", $FilterAdministratorToken)

        Write-Log -Message "UAC 配置檢測完成。" -Level "INFO"
    } catch {
        Write-Log -Message "檢測 UAC 配置時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
    }
    return $UACSettings
}

Function Set-UACPolicy {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$PolicyName,
        [Parameter(Mandatory=$true)]
        [int]$PolicyValue
    )

    if ($PSCmdlet.ShouldProcess("設定 UAC 策略 '$PolicyName' 為值 '$PolicyValue'", "您確定要執行此操作嗎？", "UAC 策略配置")) {
        try {
            Write-Log -Message "正在設定 UAC 策略 '$PolicyName' 為 '$PolicyValue'..." -Level "INFO"
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name $PolicyName -Value $PolicyValue -Force -ErrorAction Stop
            Write-Log -Message "UAC 策略 '$PolicyName' 設定成功。" -Level "INFO"
        } catch {
            Write-Log -Message "設定 UAC 策略 '$PolicyName' 時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

Function Invoke-UACHardening {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    Param()

    Write-Log -Message "開始執行 UAC 強化配置..." -Level "INFO"

    # 建議的 UAC 強化策略
    # 參考：Microsoft Learn, HackTricks
    $RecommendedPolicies = @{
        "EnableLUA" = 1; # 啟用 UAC
        "ConsentPromptBehaviorAdmin" = 2; # 管理員在管理員批准模式下提示行為：始終提示
        "LocalAccountTokenFilterPolicy" = 0; # 禁用遠程 UAC 限制，只允許內建管理員帳戶無 UAC 提示
        "FilterAdministratorToken" = 1; # 內建管理員帳戶的過濾管理員令牌：啟用
    }

    $CurrentUACSettings = Get-UACStatus
    $Report = [System.Collections.ArrayList]::new()

    foreach ($Policy in $RecommendedPolicies.GetEnumerator()) {
        $PolicyName = $Policy.Key
        $RecommendedValue = $Policy.Value
        $CurrentValue = $CurrentUACSettings[$PolicyName]

        $Status = "已配置"
        if ($CurrentValue -ne $RecommendedValue) {
            $Status = "需要更新"
            Write-Log -Message "策略 '$PolicyName' 當前值為 '$CurrentValue'，建議值為 '$RecommendedValue'。需要更新。" -Level "WARN"
            if ($PSCmdlet.ShouldProcess("更新 UAC 策略 '$PolicyName' 為 '$RecommendedValue'", "您確定要應用此強化設定嗎？", "UAC 強化")) {
                Set-UACPolicy -PolicyName $PolicyName -PolicyValue $RecommendedValue
                $CurrentUACSettings = Get-UACStatus # 重新檢測以確認更改
                if ($CurrentUACSettings[$PolicyName] -eq $RecommendedValue) {
                    $Status = "已更新"
                } else {
                    $Status = "更新失敗"
                    Write-Log -Message "策略 '$PolicyName' 更新失敗。" -Level "ERROR"
                }
            }
        }
        $Report.Add(@{
            Policy = $PolicyName;
            CurrentValue = $CurrentValue;
            RecommendedValue = $RecommendedValue;
            Status = $Status
        })
    }

    Write-Log -Message "UAC 強化配置完成。" -Level "INFO"
    return $Report
}

#endregion

#region 主執行邏輯

Write-Log -Message "B1_UAC_Hardening - UAC 強化與繞過防護模塊 啟動。" -Level "INFO"

$DetectionReport = Invoke-UACHardening

$ReportJson = $DetectionReport | ConvertTo-Json -Depth 100
Write-Log -Message "生成 UAC 強化檢測報告 (JSON 格式):" -Level "INFO"
Write-Host $ReportJson

Write-Log -Message "B1_UAC_Hardening - UAC 強化與繞過防護模塊 執行結束。" -Level "INFO"

#endregion
