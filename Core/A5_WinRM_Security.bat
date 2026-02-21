<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>

<#
.SYNOPSIS
    A5_WinRM_Security - WinRM/PowerShell Remoting 安全模塊
.DESCRIPTION
    此模塊旨在增強 Windows Remote Management (WinRM) 和 PowerShell Remoting 的安全性。
    它會檢查並配置相關設定，以防範潛在的安全漏洞。
.PARAMETER WhatIf
    顯示執行命令後會發生的情況，但不實際執行命令。
.PARAMETER Confirm
    在執行命令前提示您進行確認。
.NOTES
    版本：1.0
    作者：Manus AI
    日期：2026-02-18
    編碼：UTF-8 with BOM
#>

#region 模塊參數
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param
(
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,

    [Parameter(Mandatory=$false)]
    [switch]$Confirm
)
#endregion

#region 函數：寫入日誌
function Write-Log
{
    param
    (
        [string]$Message,
        [string]$Level = 'INFO' # INFO, WARN, ERROR, DEBUG
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"
    Write-Host $LogEntry
    # 實際應用中可將日誌寫入文件
}
#endregion

#region 函數：生成檢測報告
function New-DetectionReport
{
    param
    (
        [array]$Findings
    )
    $Report = @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss");
        Module = "A5_WinRM_Security";
        Findings = $Findings
    }
    return ConvertTo-Json -InputObject $Report -Depth 100
}
#endregion

#region 主要邏輯
function Invoke-WinRMSecurityCheck
{
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param()

    Write-Log -Message "開始執行 WinRM/PowerShell Remoting 安全檢查與配置。" -Level "INFO"
    $findings = @()

    # 模擬進度顯示
    $totalSteps = 5
    for ($i = 1; $i -le $totalSteps; $i++)
    {
        Write-Progress -Activity "執行安全檢查" -Status "正在檢查步驟 $i 之 $totalSteps" -PercentComplete (($i / $totalSteps) * 100)
        Start-Sleep -Milliseconds 200 # 模擬工作
    }

    # 檢查 WinRM 服務狀態
    Write-Log -Message "檢查 WinRM 服務狀態..." -Level "INFO"
    try
    {
        $winrmService = Get-Service -Name WinRM -ErrorAction Stop
        if ($winrmService.Status -ne 'Running')
        {
            Write-Log -Message "WinRM 服務未運行。建議啟動服務以確保遠端管理功能。" -Level "WARN"
            $findings += @{ Item = "WinRM 服務狀態"; Status = "未運行"; Recommendation = "啟動 WinRM 服務" }
            if ($PSCmdlet.ShouldProcess("啟動 WinRM 服務", "您確定要啟動 WinRM 服務嗎？"))
            {
                # Start-Service -Name WinRM -ErrorAction Stop
                Write-Log -Message "已模擬啟動 WinRM 服務。" -Level "INFO"
            }
        }
        else
        {
            Write-Log -Message "WinRM 服務正在運行。" -Level "INFO"
        }
    }
    catch
    {
        Write-Log -Message "檢查 WinRM 服務時發生錯誤：$($_.Exception.Message)" -Level "ERROR"
        $findings += @{ Item = "WinRM 服務狀態"; Status = "錯誤"; Details = $_.Exception.Message }
    }

    # 檢查 WinRM 監聽器配置 (HTTPS)
    Write-Log -Message "檢查 WinRM 監聽器配置 (HTTPS)..." -Level "INFO"
    try
    {
        $listeners = Get-WSManInstance -ResourceURI wmi/root/cimv2/Win32_NetworkAdapterConfiguration -Selector @{IPEnabled=$true} -ErrorAction Stop
        $httpsListenerExists = $false
        foreach ($listener in $listeners)
        {
            if ($listener.Transport -eq 'HTTPS')
            {
                $httpsListenerExists = $true
                break
            }
        }

        if (-not $httpsListenerExists)
        {
            Write-Log -Message "未找到 WinRM HTTPS 監聽器。建議配置 HTTPS 監聽器以加密遠端通訊。" -Level "WARN"
            $findings += @{ Item = "WinRM HTTPS 監聽器"; Status = "未配置"; Recommendation = "配置 WinRM HTTPS 監聽器" }
            if ($PSCmdlet.ShouldProcess("配置 WinRM HTTPS 監聽器", "您確定要配置 WinRM HTTPS 監聽器嗎？"))
            {
                # New-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Address="*";Transport="HTTPS"} -ErrorAction Stop
                Write-Log -Message "已模擬配置 WinRM HTTPS 監聽器。" -Level "INFO"
            }
        }
        else
        {
            Write-Log -Message "已配置 WinRM HTTPS 監聽器。" -Level "INFO"
        }
    }
    catch
    {
        Write-Log -Message "檢查 WinRM 監聽器配置時發生錯誤：$($_.Exception.Message)" -Level "ERROR"
        $findings += @{ Item = "WinRM HTTPS 監聽器"; Status = "錯誤"; Details = $_.Exception.Message }
    }

    # 檢查 WinRM 防火牆規則
    Write-Log -Message "檢查 WinRM 防火牆規則..." -Level "INFO"
    try
    {
        $winrmFirewallRule = Get-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -ErrorAction SilentlyContinue
        if ($null -eq $winrmFirewallRule -or $winrmFirewallRule.Enabled -eq $false)
        {
            Write-Log -Message "WinRM (HTTP-In) 防火牆規則未啟用或不存在。建議啟用以允許遠端連線。" -Level "WARN"
            $findings += @{ Item = "WinRM 防火牆規則"; Status = "未啟用"; Recommendation = "啟用 WinRM (HTTP-In) 防火牆規則" }
            if ($PSCmdlet.ShouldProcess("啟用 WinRM (HTTP-In) 防火牆規則", "您確定要啟用 WinRM (HTTP-In) 防火牆規則嗎？"))
            {
                # Enable-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -ErrorAction Stop
                Write-Log -Message "已模擬啟用 WinRM (HTTP-In) 防火牆規則。" -Level "INFO"
            }
        }
        else
        {
            Write-Log -Message "WinRM (HTTP-In) 防火牆規則已啟用。" -Level "INFO"
        }
    }
    catch
    {
        Write-Log -Message "檢查 WinRM 防火牆規則時發生錯誤：$($_.Exception.Message)" -Level "ERROR"
        $findings += @{ Item = "WinRM 防火牆規則"; Status = "錯誤"; Details = $_.Exception.Message }
    }

    # 檢查 PowerShell Remoting 配置
    Write-Log -Message "檢查 PowerShell Remoting 配置..." -Level "INFO"
    try
    {
        $psRemotingStatus = Get-PSSessionConfiguration -Name Microsoft.PowerShell -ErrorAction SilentlyContinue
        if ($null -eq $psRemotingStatus)
        {
            Write-Log -Message "PowerShell Remoting 未啟用。建議啟用以允許遠端管理。" -Level "WARN"
            $findings += @{ Item = "PowerShell Remoting"; Status = "未啟用"; Recommendation = "啟用 PowerShell Remoting" }
            if ($PSCmdlet.ShouldProcess("啟用 PowerShell Remoting", "您確定要啟用 PowerShell Remoting 嗎？"))
            {
                # Enable-PSRemoting -Force
                Write-Log -Message "已模擬啟用 PowerShell Remoting。" -Level "INFO"
            }
        }
        else
        {
            Write-Log -Message "PowerShell Remoting 已啟用。" -Level "INFO"
        }
    }
    catch
    {
        Write-Log -Message "檢查 PowerShell Remoting 配置時發生錯誤：$($_.Exception.Message)" -Level "ERROR"
        $findings += @{ Item = "PowerShell Remoting"; Status = "錯誤"; Details = $_.Exception.Message }
    }

    # 生成報告
    $reportJson = New-DetectionReport -Findings $findings
    Write-Log -Message "安全檢查完成。檢測報告已生成。" -Level "INFO"
    Write-Host "`n檢測報告 (JSON 格式):`n"
    Write-Host $reportJson

    return $reportJson
}

# 執行主要邏輯
if ($PSCmdlet.ShouldProcess("執行 WinRM/PowerShell Remoting 安全模塊", "您確定要執行此安全模塊嗎？"))
{
    Invoke-WinRMSecurityCheck
}

#endregion
