<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>

<#
.SYNOPSIS
    E1_Memory_Mitigation - 記憶體溢出漏洞緩解模塊

.DESCRIPTION
    此腳本用於配置和檢查 Windows 系統的記憶體保護機制，特別是資料執行防止 (DEP) 和位址空間配置隨機化 (ASLR)。
    它提供了啟用、停用和查詢這些緩解措施的功能，並支援詳細日誌記錄、錯誤處理、WhatIf 和 Confirm 功能。

.PARAMETER EnableDep
    指定是否啟用系統範圍的 DEP。接受布林值 $true 或 $false。

.PARAMETER EnableAslr
    指定是否啟用系統範圍的 ASLR。接受布林值 $true 或 $false。

.PARAMETER GenerateReport
    指定是否生成 JSON 格式的檢測報告。接受布林值 $true 或 $false。

.PARAMETER LogPath
    指定日誌檔案的儲存路徑。如果未指定，將預設儲存到腳本所在目錄。

.EXAMPLE
    .'E1_Memory_Mitigation.ps1' -EnableDep $true -EnableAslr $true -GenerateReport $true
    啟用 DEP 和 ASLR，並生成檢測報告。

.EXAMPLE
    .'E1_Memory_Mitigation.ps1' -GenerateReport $true -WhatIf
    預覽生成檢測報告的操作，但不實際執行。

.EXAMPLE
    .'E1_Memory_Mitigation.ps1' -EnableDep $false -Confirm
    停用 DEP，並在執行前要求確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    編碼：UTF-8 with BOM
#>

#region 腳本配置
$PSDefaultParameterValues['*:Confirm'] = $true
$PSDefaultParameterValues['*:WhatIf'] = $false

#region 函數定義

Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Level = 'INFO',
        [string]$LogFile
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
    Write-Host $LogEntry
}

Function Get-DepStatus {
    [CmdletBinding()]
    Param(
        [string]$LogFile
    )
    Write-Log -Message "正在獲取 DEP 狀態..." -LogFile $LogFile
    try {
        $depStatus = (wmic OS Get DataExecutionPrevention_Available,DataExecutionPrevention_Drivers,DataExecutionPrevention_SupportPolicy /value | Select-String -Pattern '(?<=^DataExecutionPrevention_SupportPolicy=).*' | ForEach-Object {$_.Matches.Value} | Out-String).Trim()
        switch ($depStatus) {
            "0" { $status = "AlwaysOff" }
            "1" { $status = "AlwaysOn" }
            "2" { $status = "OptIn" }
            "3" { $status = "OptOut" }
            default { $status = "未知" }
        }
        Write-Log -Message "DEP 狀態：$status" -LogFile $LogFile
        return $status
    }
    catch {
        Write-Log -Message "獲取 DEP 狀態失敗: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile
        return "錯誤"
    }
}

Function Set-DepStatus {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$true)]
        [boolean]$Enable,
        [string]$LogFile
    )

    $action = If ($Enable) {"啟用"} Else {"停用"}
    If ($PSCmdlet.ShouldProcess("DEP", "$action DEP")) {
        Write-Log -Message "正在嘗試 $action DEP..." -LogFile $LogFile
        try {
            # 0: AlwaysOff, 1: AlwaysOn, 2: OptIn, 3: OptOut
            $policy = If ($Enable) {1} Else {0}
            # Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DataExecutionPrevention_SupportPolicy" -Value $policy -Force
            # 由於直接修改註冊表可能需要重啟且影響較大，這裡使用 bcdedit 命令進行更安全的配置
            If ($Enable) {
                $command = "bcdedit.exe /set {current} nx AlwaysOn"
            } Else {
                $command = "bcdedit.exe /set {current} nx AlwaysOff"
            }
            Invoke-Expression $command

            If ($LASTEXITCODE -eq 0) {
                Write-Log -Message "$action DEP 成功。可能需要重啟系統以生效。" -LogFile $LogFile
                return $true
            } Else {
                Write-Log -Message "$action DEP 失敗。bcdedit 命令返回錯誤碼 $LASTEXITCODE。" -Level 'ERROR' -LogFile $LogFile
                return $false
            }
        }
        catch {
            Write-Log -Message "$action DEP 失敗: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile
            return $false
        }
    }
    return $false
}

Function Get-AslrStatus {
    [CmdletBinding()]
    Param(
        [string]$LogFile
    )
    Write-Log -Message "正在獲取 ASLR 狀態..." -LogFile $LogFile
    try {
        # ASLR 狀態通常通過 Exploit Protection 設置來管理
        # 獲取 Exploit Protection 設置需要 Get-MpPreference 或 Get-ProcessMitigation
        # 這裡使用 Get-ProcessMitigation -System 來獲取系統級別的 ASLR 設置
        $aslr = Get-ProcessMitigation -System | Select-Object -ExpandProperty ASLR
        $status = If ($aslr.Enable) {"已啟用"} Else {"已停用"}
        Write-Log -Message "ASLR 狀態：$status" -LogFile $LogFile
        return $status
    }
    catch {
        Write-Log -Message "獲取 ASLR 狀態失敗: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogFile
        return "錯誤"
    }
}

Function Set-AslrStatus {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$true)]
        [boolean]$Enable,
        [string]$LogFile
    )

    $action = If ($Enable) {"啟用"} Else {"停用"}
    If ($PSCmdlet.ShouldProcess("ASLR", "$action ASLR")) {
        Write-Log -Message "正在嘗試 $action ASLR..." -LogFile $LogFile
        try {
            # 設置 ASLR 通常通過 Set-ProcessMitigation -System -ASLR <boolean> 來完成
            # 但此命令在某些 Windows 版本中可能需要更精細的控制或不直接支援系統級別的全局開關
            # 更通用的方法是通過 Exploit Protection GUI 或組策略
            # 這裡我們嘗試使用 Set-ProcessMitigation -System -ASLR ForceRelocateImages:$Enable,BottomUp:$Enable
            # 注意：這會影響所有進程，可能需要重啟才能完全生效
            Set-ProcessMitigation -System -ASLR ForceRelocateImages:$Enable,BottomUp:$Enable -ErrorAction Stop

            Write-Log -Message "$action ASLR 成功。可能需要重啟系統以生效。" -LogFile $LogFile
            return $true
        }
        catch {
            Write-Log -Message "$action ASLR 失敗: $($_.Exception.Message)。請檢查您的 PowerShell 版本和權限。" -Level 'ERROR' -LogFile $LogFile
            return $false
        }
    }
    return $false
}

#endregion

#region 主腳本邏輯

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
Param(
    [Parameter(HelpMessage="指定是否啟用系統範圍的 DEP。")]
    [boolean]$EnableDep,

    [Parameter(HelpMessage="指定是否啟用系統範圍的 ASLR。")]
    [boolean]$EnableAslr,

    [Parameter(HelpMessage="指定是否生成 JSON 格式的檢測報告。")]
    [boolean]$GenerateReport = $false,

    [Parameter(HelpMessage="指定日誌檔案的儲存路徑。")]
    [string]$LogPath = (Join-Path $PSScriptRoot "E1_Memory_Mitigation.log")
)

# 確保日誌目錄存在
$LogDirectory = Split-Path -Path $LogPath -Parent
If (-not (Test-Path $LogDirectory)) {
    New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
}

Write-Log -Message "腳本開始執行..." -LogFile $LogPath

$report = @{
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Module = "E1_Memory_Mitigation"
    ActionsPerformed = @()
    CurrentStatus = @{}
    Errors = @()
}

# 處理 DEP 設置
If ($PSBoundParameters.ContainsKey('EnableDep')) {
    $actionMessage = "配置 DEP 為 $($EnableDep ? '啟用' : '停用')"
    Write-Progress -Activity "記憶體緩解模塊" -Status $actionMessage -PercentComplete 25
    If ($PSCmdlet.ShouldProcess("DEP", $actionMessage)) {
        $depResult = Set-DepStatus -Enable $EnableDep -LogFile $LogPath
        $report.ActionsPerformed += @{ Action = "Set DEP"; Enabled = $EnableDep; Success = $depResult }
    }
}

# 處理 ASLR 設置
If ($PSBoundParameters.ContainsKey('EnableAslr')) {
    $actionMessage = "配置 ASLR 為 $($EnableAslr ? '啟用' : '停用')"
    Write-Progress -Activity "記憶體緩解模塊" -Status $actionMessage -PercentComplete 50
    If ($PSCmdlet.ShouldProcess("ASLR", $actionMessage)) {
        $aslrResult = Set-AslrStatus -Enable $EnableAslr -LogFile $LogPath
        $report.ActionsPerformed += @{ Action = "Set ASLR"; Enabled = $EnableAslr; Success = $aslrResult }
    }
}

# 獲取當前狀態
Write-Progress -Activity "記憶體緩解模塊" -Status "正在獲取當前記憶體保護狀態..." -PercentComplete 75
$report.CurrentStatus.Dep = Get-DepStatus -LogFile $LogPath
$report.CurrentStatus.Aslr = Get-AslrStatus -LogFile $LogPath

# 生成報告
If ($GenerateReport) {
    $reportPath = (Join-Path $PSScriptRoot "E1_Memory_Mitigation_Report.json")
    Write-Log -Message "正在生成 JSON 報告到 $reportPath..." -LogFile $LogPath
    try {
        $report | ConvertTo-Json -Depth 100 | Set-Content -Path $reportPath -Encoding UTF8 -Force
        Write-Log -Message "JSON 報告生成成功。" -LogFile $LogPath
        $report.ReportPath = $reportPath
    }
    catch {
        Write-Log -Message "生成 JSON 報告失敗: $($_.Exception.Message)" -Level 'ERROR' -LogFile $LogPath
        $report.Errors += "生成 JSON 報告失敗: $($_.Exception.Message)"
    }
}

Write-Progress -Activity "記憶體緩解模塊" -Status "腳本執行完成" -PercentComplete 100 -Completed
Write-Log -Message "腳本執行完成。" -LogFile $LogPath

# 輸出報告對象，以便其他腳本或調用者使用
$report | ConvertTo-Json -Depth 100

#endregion
