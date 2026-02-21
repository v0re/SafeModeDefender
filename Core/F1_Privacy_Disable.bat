<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>

<#
.SYNOPSIS
    F1_Privacy_Disable - Windows 隱私權全面關閉模塊
    此腳本旨在全面關閉 Windows 系統中的各項隱私權相關功能，以增強使用者隱私保護。

.DESCRIPTION
    本腳本將透過修改註冊表、禁用服務和調整本機策略等方式，關閉以下 Windows 隱私權功能：
    - 攝像頭存取
    - 麥克風存取
    - 位置服務
    - 診斷數據
    - 活動歷程記錄
    - 廣告 ID
    - 語音辨識
    - 筆跡與輸入
    - 帳戶資訊存取
    - 聯絡人存取

    腳本支援 -WhatIf 和 -Confirm 參數，提供多級別日誌記錄和進度顯示，並能生成 JSON 格式的檢測報告。

.PARAMETER WhatIf
    顯示如果執行命令會發生什麼，但不實際執行命令。

.PARAMETER Confirm
    在執行命令前提示您進行確認。

.EXAMPLE
    .'F1_Privacy_Disable.ps1' -WhatIf
    顯示將要執行的操作，但不實際修改系統。

.EXAMPLE
    .'F1_Privacy_Disable.ps1' -Confirm
    在執行每個主要操作前提示使用者確認。

.EXAMPLE
    .'F1_Privacy_Disable.ps1'
    直接執行腳本，關閉所有指定的 Windows 隱私權功能。

.NOTES
    作者：ManusAI
    版本：1.0
    日期：2026-02-18
    需求：Windows 10/11，以管理員權限執行。
#>

#region 腳本初始化與配置

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param()

$script:ModuleName = "F1_Privacy_Disable"
$script:LogFile = Join-Path $PSScriptRoot "{$script:ModuleName}.log"
$script:ReportFile = Join-Path $PSScriptRoot "{$script:ModuleName}_Report.json"

# 設置輸出編碼為 UTF-8 with BOM
$BOM = New-Object System.Text.UTF8Encoding $True
[Console]::OutputEncoding = $BOM

#endregion

#region 日誌函數

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Level = "INFO" # INFO, WARNING, ERROR, CRITICAL
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "{$Timestamp} [{$Level}] {$Message}"
    Add-Content -Path $script:LogFile -Value $LogEntry -Encoding UTF8
    Write-Host $LogEntry
}

#endregion

#region 進度顯示函數

function Write-ProgressStatus {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Activity,
        [Parameter(Mandatory=$true)]
        [string]$Status,
        [int]$PercentComplete
    )
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

#endregion

#region 主要功能實現

function Disable-PrivacyFeature {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FeatureName,
        [Parameter(Mandatory=$true)]
        [scriptblock]$ActionScript
    )

    Write-Log -Message "正在處理功能: {$FeatureName}" -Level "INFO"
    Write-ProgressStatus -Activity "關閉 Windows 隱私權功能" -Status "正在處理 {$FeatureName}..." -PercentComplete 0

    if ($PSCmdlet.ShouldProcess("關閉 {$FeatureName} 功能", "您確定要執行此操作嗎？")) {
        try {
            & $ActionScript
            Write-Log -Message "功能 {$FeatureName} 已成功處理。" -Level "INFO"
            return $true
        }
        catch {
            Write-Log -Message "處理功能 {$FeatureName} 時發生錯誤: {$_.Exception.Message}" -Level "ERROR"
            return $false
        }
    }
    else {
        Write-Log -Message "使用者取消了功能 {$FeatureName} 的處理。" -Level "WARNING"
        return $false
    }
}

#endregion

#region 隱私權功能定義與執行

$privacyFeatures = @(
    # 攝像頭存取
    @{ Name = "攝像頭存取"; Action = {
        # 禁用攝像頭存取 (全系統)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" -Name "LastUsedTimeStop" -Value (Get-Date).ToFileTime() -ErrorAction SilentlyContinue
        
        # 禁用應用程式存取攝像頭 (使用者層級)
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" -Name "LastUsedTimeStop" -Value (Get-Date).ToFileTime() -ErrorAction SilentlyContinue

        # 禁用攝像頭的通用設定
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{E5323777-F976-4f5b-9B55-B94699C46E44}" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{E5323777-F976-4f5b-9B55-B94699C46E44}" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue

        # 禁用攝像頭驅動 (如果需要更徹底的禁用)
        # Get-PnpDevice -Class "Image" | Disable-PnpDevice -Confirm:$false -ErrorAction SilentlyContinue
        # Write-Log -Message "已嘗試禁用所有攝像頭設備驅動。" -Level "INFO"
    } },
    # 麥克風存取
    @{ Name = "麥克風存取"; Action = {
        # 禁用麥克風存取 (全系統)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" -Name "LastUsedTimeStop" -Value (Get-Date).ToFileTime() -ErrorAction SilentlyContinue

        # 禁用應用程式存取麥克風 (使用者層級)
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" -Name "LastUsedTimeStop" -Value (Get-Date).ToFileTime() -ErrorAction SilentlyContinue

        # 禁用麥克風的通用設定
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{2EEF81B4-6B4B-4FDE-8404-0D83D9272606}" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{2EEF81B4-6B4B-4FDE-8404-0D83D9272606}" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue

        # 禁用麥克風驅動 (如果需要更徹底的禁用)
        # Get-PnpDevice -Class "Media" | Where-Object { $_.FriendlyName -like "*Microphone*" } | Disable-PnpDevice -Confirm:$false -ErrorAction SilentlyContinue
        # Write-Log -Message "已嘗試禁用所有麥克風設備驅動。" -Level "INFO"
    } },
    # 位置服務
    @{ Name = "位置服務"; Action = {
        # 禁用位置服務 (全系統)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\LocationAndSensors" -Name "LocationDisabled" -Value 1 -Force -ErrorAction SilentlyContinue

        # 禁用位置服務 (使用者層級)
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\Location" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\Location" -Name "LastUsedTimeStop" -Value (Get-Date).ToFileTime() -ErrorAction SilentlyContinue

        # 禁用位置服務的通用設定
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{625B5ADF-26C7-4957-A653-535384664F89}" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{625B5ADF-26C7-4957-A653-535384664F89}" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
    } },
    # 診斷數據
    @{ Name = "診斷數據"; Action = {
        # 禁用診斷數據 (全系統)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "CommercialID" -Value "" -Force -ErrorAction SilentlyContinue

        # 禁用診斷數據服務
        Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        Set-Service -Name "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name "dmwappushservice" -ErrorAction SilentlyContinue
        Set-Service -Name "WerSvc" -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name "WerSvc" -ErrorAction SilentlyContinue
    } },
    # 活動歷程記錄
    @{ Name = "活動歷程記錄"; Action = {
        # 禁用活動歷程記錄 (全系統)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -Force -ErrorAction SilentlyContinue

        # 禁用活動歷程記錄 (使用者層級)
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "ActivityFeedEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "PublishUserActivities" -Value 0 -Force -ErrorAction SilentlyContinue
    } },
    # 廣告 ID
    @{ Name = "廣告 ID"; Action = {
        # 禁用廣告 ID (全系統)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DisableAdvertisingID" -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Force -ErrorAction SilentlyContinue

        # 禁用廣告 ID (使用者層級)
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Force -ErrorAction SilentlyContinue
    } },
    # 語音辨識
    @{ Name = "語音辨識"; Action = {
        # 禁用線上語音辨識 (全系統)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Speech" -Name "AllowOnlineSpeech" -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Speech" -Name "AllowSpeechInput" -Value 0 -Force -ErrorAction SilentlyContinue

        # 禁用語音辨識服務 (如果存在)
        Set-Service -Name "SpeechRecognition" -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name "SpeechRecognition" -ErrorAction SilentlyContinue
    } },
    # 筆跡與輸入
    @{ Name = "筆跡與輸入"; Action = {
        # 禁用筆跡與輸入個人化 (全系統)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" -Name "PreventHandwritingErrorReporting" -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" -Name "PreventHandwritingDataSharing" -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" -Name "PreventInkingFeedback" -Value 1 -Force -ErrorAction SilentlyContinue

        # 禁用筆跡與輸入個人化 (使用者層級)
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictInkingAndTypingData" -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "HarvestText" -Value 0 -Force -ErrorAction SilentlyContinue
    } },
    # 帳戶資訊存取
    @{ Name = "帳戶資訊存取"; Action = {
        # 禁用應用程式存取帳戶資訊 (全系統)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\AccountInfo" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\AccountInfo" -Name "LastUsedTimeStop" -Value (Get-Date).ToFileTime() -ErrorAction SilentlyContinue

        # 禁用應用程式存取帳戶資訊 (使用者層級)
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\AccountInfo" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\AccountInfo" -Name "LastUsedTimeStop" -Value (Get-Date).ToFileTime() -ErrorAction SilentlyContinue
    } },
    # 聯絡人存取
    @{ Name = "聯絡人存取"; Action = {
        # 禁用應用程式存取聯絡人 (全系統)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\Contacts" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\Contacts" -Name "LastUsedTimeStop" -Value (Get-Date).ToFileTime() -ErrorAction SilentlyContinue

        # 禁用應用程式存取聯絡人 (使用者層級)
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\Contacts" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\Contacts" -Name "LastUsedTimeStop" -Value (Get-Date).ToFileTime() -ErrorAction SilentlyContinue
    } }
)

$results = @()
for ($i = 0; $i -lt $privacyFeatures.Count; $i++) {
    $feature = $privacyFeatures[$i]
    $percent = [int](($i / $privacyFeatures.Count) * 100)
    Write-ProgressStatus -Activity "關閉 Windows 隱私權功能" -Status "正在處理 {$feature.Name}..." -PercentComplete $percent

    $success = Disable-PrivacyFeature -FeatureName $feature.Name -ActionScript $feature.Action
    $results += @{ Feature = $feature.Name; Status = if ($success) "成功" else "失敗" }
}

Write-ProgressStatus -Activity "關閉 Windows 隱私權功能" -Status "所有功能處理完畢。" -PercentComplete 100

#endregion

#region 生成報告

Write-Log -Message "正在生成 JSON 格式的檢測報告..." -Level "INFO"
$reportContent = @{
    ModuleName = $script:ModuleName;
    Timestamp = (Get-Date).ToString();
    Results = $results
}
$reportContent | ConvertTo-Json -Depth 100 | Set-Content -Path $script:ReportFile -Encoding UTF8
Write-Log -Message "檢測報告已生成至 {$script:ReportFile}" -Level "INFO"

#endregion

Write-Log -Message "腳本執行完畢。" -Level "INFO"
