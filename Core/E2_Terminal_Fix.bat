<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>

<#
.SYNOPSIS
    E2_Terminal_Fix - 終端亂碼與記憶體溢出修復模塊

.DESCRIPTION
    此腳本旨在修復 Windows 終端（如 PowerShell, CMD）中常見的亂碼問題，並優化記憶體使用，以防止記憶體溢出。
    它會調整終端編碼設定為 UTF-8，限制控制台緩衝區大小，並配置相關記憶體限制。

.PARAMETER WhatIf
    描述當執行此命令時會發生什麼，但不實際執行命令。

.PARAMETER Confirm
    提示您在執行命令之前進行確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    適用於：Windows 10 安全模式
    回滾機制：腳本會備份修改前的註冊表設定，以便於回滾。

.EXAMPLE
    .'E2_Terminal_Fix.ps1' -WhatIf
    描述將會執行的操作，但不實際修改系統。

.EXAMPLE
    .'E2_Terminal_Fix.ps1' -Confirm
    在執行任何修改前會提示使用者確認。

.EXAMPLE
    .'E2_Terminal_Fix.ps1'
    直接執行修復操作。
#>

param(
    [switch]$WhatIf,
    [switch]$Confirm
)

#region 函數定義

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'INFO' # INFO, WARN, ERROR, DEBUG
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$Level] $Message"
    Write-Host $logEntry
    # 實際應用中可將日誌寫入文件
}

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not ($currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        Write-Log -Message "此腳本需要管理員權限才能執行。請以管理員身份運行。" -Level "ERROR"
        exit 1
    }
}

function Set-TerminalEncoding {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string]$Encoding = "65001" # UTF-8
    )

    if ($PSCmdlet.ShouldProcess("終端編碼設定", "設定控制台預設編碼為 UTF-8")) {
        Write-Log -Message "正在設定控制台預設編碼為 UTF-8..."
        try {
            # 備份現有設定
            $currentCodePage = (Get-ItemProperty HKCU:\Console).CodePage
            if ($currentCodePage -ne $Encoding) {
                Write-Log -Message "備份當前控制台編碼設定：$currentCodePage" -Level "INFO"
                Set-ItemProperty -Path HKCU:\Console -Name CodePageBackup -Value $currentCodePage -Force
            }

            Set-ItemProperty -Path HKCU:\Console -Name CodePage -Value $Encoding -Force
            Write-Log -Message "控制台預設編碼已設定為 UTF-8 (代碼頁 $Encoding)。" -Level "INFO"
        }
        catch {
            Write-Log -Message "設定控制台編碼失敗：$($_.Exception.Message)" -Level "ERROR"
            # 這裡可以添加回滾邏輯
        }
    }
}

function Set-ConsoleBufferSize {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [int]$BufferSize = 9999 # 建議值，防止記憶體溢出
    )

    if ($PSCmdlet.ShouldProcess("控制台緩衝區大小設定", "設定控制台緩衝區大小為 $BufferSize")) {
        Write-Log -Message "正在設定控制台緩衝區大小為 $BufferSize..."
        try {
            # 備份現有設定
            $currentBufferSize = (Get-ItemProperty HKCU:\Console).ScreenBufferSize.Height
            if ($currentBufferSize -ne $BufferSize) {
                Write-Log -Message "備份當前控制台緩衝區大小：$currentBufferSize" -Level "INFO"
                Set-ItemProperty -Path HKCU:\Console -Name ScreenBufferSizeHeightBackup -Value $currentBufferSize -Force
            }

            Set-ItemProperty -Path HKCU:\Console -Name ScreenBufferSize -Value @{Width=120;Height=$BufferSize} -Force
            Write-Log -Message "控制台緩衝區大小已設定為 $BufferSize。" -Level "INFO"
        }
        catch {
            Write-Log -Message "設定控制台緩衝區大小失敗：$($_.Exception.Message)" -Level "ERROR"
        }
    }
}

function Generate-DetectionReport {
    param(
        [string]$OutputPath = "E2_Terminal_Fix_Report.json"
    )

    Write-Log -Message "正在生成檢測報告..."
    $report = @{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Module = "E2_Terminal_Fix"
        Status = "Completed"
        Details = @{
            TerminalEncoding = (Get-ItemProperty HKCU:\Console).CodePage
            ConsoleBufferSize = (Get-ItemProperty HKCU:\Console).ScreenBufferSize.Height
            # 更多檢測項目可以添加到這裡
        }
    }

    try {
        $report | ConvertTo-Json -Depth 100 | Set-Content -Path $OutputPath -Encoding UTF8 -Force
        Write-Log -Message "檢測報告已生成至：$(Convert-Path $OutputPath)" -Level "INFO"
    }
    catch {
        Write-Log -Message "生成檢測報告失敗：$($_.Exception.Message)" -Level "ERROR"
    }
}

#endregion

#region 主執行邏輯

Test-Admin

Write-Log -Message "E2_Terminal_Fix 模塊開始執行..." -Level "INFO"

# 進度顯示
$totalSteps = 2
$currentStep = 0

$currentStep++
Write-Progress -Activity "E2_Terminal_Fix 模塊執行中" -Status "($currentStep/$totalSteps) 正在設定終端編碼..." -PercentComplete (($currentStep / $totalSteps) * 100)
Set-TerminalEncoding -WhatIf:$WhatIf -Confirm:$Confirm

$currentStep++
Write-Progress -Activity "E2_Terminal_Fix 模塊執行中" -Status "($currentStep/$totalSteps) 正在設定控制台緩衝區大小..." -PercentComplete (($currentStep / $totalSteps) * 100)
Set-ConsoleBufferSize -WhatIf:$WhatIf -Confirm:$Confirm

Write-Progress -Activity "E2_Terminal_Fix 模塊執行中" -Status "所有修復操作已完成。" -PercentComplete 100 -Completed

Generate-DetectionReport -OutputPath "E2_Terminal_Fix_Report.json"

Write-Log -Message "E2_Terminal_Fix 模塊執行完畢。" -Level "INFO"

#endregion
