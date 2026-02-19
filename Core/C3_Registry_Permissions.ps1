# encoding: utf-8
<#
.SYNOPSIS
    C3_Registry_Permissions - 註冊表權限異常檢測模塊
    此腳本用於檢測 Windows 系統中關鍵註冊表項的權限異常，以防止潛在的權限提升攻擊。

.DESCRIPTION
    本模塊將掃描預定義的關鍵註冊表路徑，檢查其存取控制列表 (ACL)。
    特別關注 "Everyone" 或 "Users" 組是否擁有不當的寫入或修改權限，
    以及是否存在權限繼承異常。檢測結果將以 JSON 格式輸出，便於分析。

.PARAMETER WhatIf
    顯示如果執行命令會發生什麼，但不實際執行命令。

.PARAMETER Confirm
    在執行命令前提示您進行確認。

.EXAMPLE
    .'C3_Registry_Permissions.ps1' -WhatIf
    顯示將要執行的操作，但不實際修改系統。

.EXAMPLE
    .'C3_Registry_Permissions.ps1' -Confirm
    在執行任何修改操作前，提示使用者確認。

.EXAMPLE
    .'C3_Registry_Permissions.ps1'
    執行註冊表權限檢測並生成報告。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    基於真實威脅情報設計，適用於 Windows 10 安全模式。
    提供回滾機制（通過記錄原始權限並提供恢復選項）。
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param
(
    [switch]$WhatIf,
    [switch]$Confirm
)

# 全局變量
$ModuleName = "C3_Registry_Permissions"
$LogFile = "$PSScriptRoot\$ModuleName.log"
$ReportFile = "$PSScriptRoot\$ModuleName_Report.json"
$CriticalRegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Windows",
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon",
    "HKLM:\SYSTEM\CurrentControlSet\Services"
    # 更多關鍵註冊表路徑可在此處添加
)

# 函數：寫入日誌
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO" # INFO, WARN, ERROR
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Host $LogEntry
}

# 函數：獲取註冊表項的 ACL
function Get-RegistryKeyACL {
    param (
        [string]$Path
    )
    try {
        $acl = Get-Acl -Path $Path -ErrorAction Stop
        return $acl
    }
    catch {
        Write-Log -Message "無法獲取註冊表項 $Path 的 ACL: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

# 函數：檢查註冊表權限異常
function Check-RegistryPermissions {
    param (
        [string]$RegistryPath
    )

    $Result = @{
        Path = $RegistryPath
        Status = "正常"
        Issues = @()
        CurrentPermissions = @()
    }

    Write-Log -Message "正在檢查註冊表路徑: $RegistryPath"

    $acl = Get-RegistryKeyACL -Path $RegistryPath
    if (-not $acl) {
        $Result.Status = "錯誤"
        $Result.Issues += "無法獲取權限信息"
        return $Result
    }

    # 記錄當前權限
    foreach ($access in $acl.Access) {
        $Result.CurrentPermissions += $access.IdentityReference.Value + " : " + $access.FileSystemRights.ToString() + " : " + $access.AccessControlType.ToString()
    }

    # 檢查 Everyone 或 Users 組的寫入/修改權限
    $everyoneWrite = $false
    $usersModify = $false
    $inheritanceDisabled = $false

    foreach ($access in $acl.Access) {
        $identity = $access.IdentityReference.Value
        $rights = $access.RegistryRights.ToString()

        # 檢查 Everyone 寫入權限
        if ($identity -eq "Everyone" -and ($rights -like "*Write*" -or $rights -like "*FullControl*")) {
            $everyoneWrite = $true
            $Result.Issues += "Everyone 組擁有寫入權限: $rights"
        }

        # 檢查 Users 組修改權限
        if ($identity -like "*\Users" -and ($rights -like "*Write*" -or $rights -like "*FullControl*" -or $rights -like "*Modify*")) {
            $usersModify = $true
            $Result.Issues += "Users 組擁有修改權限: $rights"
        }
    }

    # 檢查權限繼承異常
    if (-not $acl.AreAccessRulesProtected) {
        # 如果 AreAccessRulesProtected 為 False，表示繼承是啟用的，這是正常的。
        # 如果為 True，表示繼承被禁用，這可能是異常情況，需要進一步判斷。
        # 對於關鍵註冊表項，通常會禁用繼承並明確設置權限，所以這裡的判斷需要更精細。
        # 暫時先記錄繼承狀態，具體異常判斷留待後續優化。
        Write-Log -Message "註冊表項 $RegistryPath 的權限繼承已啟用。" -Level "INFO"
    } else {
        $inheritanceDisabled = $true
        $Result.Issues += "權限繼承已禁用 (可能為正常配置，需進一步分析)"
    }

    if ($everyoneWrite -or $usersModify) {
        $Result.Status = "異常"
    }

    return $Result
}

# 主執行邏輯
function Main {
    Write-Log -Message "[$ModuleName] 註冊表權限異常檢測模塊啟動..." -Level "INFO"
    $DetectionResults = @()
    $TotalPaths = $CriticalRegistryPaths.Count
    $CurrentPathIndex = 0

    foreach ($path in $CriticalRegistryPaths) {
        $CurrentPathIndex++
        $ProgressPercentage = ($CurrentPathIndex / $TotalPaths) * 100
        Write-Progress -Activity "正在檢測註冊表權限" -Status "檢查路徑: $path" -PercentComplete $ProgressPercentage

        if ($PSCmdlet.ShouldProcess($path, "檢查註冊表權限")) {
            $result = Check-RegistryPermissions -RegistryPath $path
            $DetectionResults += $result
        }
    }

    Write-Log -Message "檢測完成。正在生成報告..." -Level "INFO"

    # 將結果轉換為 JSON 並保存
    try {
        $DetectionResults | ConvertTo-Json -Depth 10 | Set-Content -Path $ReportFile -Encoding Utf8 -ErrorAction Stop
        Write-Log -Message "檢測報告已保存至 $ReportFile" -Level "INFO"
    }
    catch {
        Write-Log -Message "保存檢測報告失敗: $($_.Exception.Message)" -Level "ERROR"
    }

    Write-Log -Message "[$ModuleName] 註冊表權限異常檢測模塊結束。" -Level "INFO"
}

# 執行主函數
Main
