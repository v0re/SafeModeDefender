
```powershell
# H1_Environment_Variables.ps1
# 環境變數安全檢測模塊

<#
.SYNOPSIS
    此腳本用於檢測和修復 Windows 環境變數中的安全問題，例如 PATH 劫持和 DLL 搜尋順序攻擊。

.DESCRIPTION
    H1_Environment_Variables 模塊會執行以下操作：
    1. 審計系統和使用者 PATH 環境變數，查找可疑或不安全的條目。
    2. 檢測 PATH 中可寫的目錄，這些目錄可能被用於 DLL 劫持。
    3. 分析 DLL 搜尋順序，識別潛在的弱點。
    4. 檢測其他可疑的系統或使用者環境變數。
    5. 提供修復建議，並在 -WhatIf 模式下顯示將執行的操作。
    6. 在 -Confirm 模式下，允許使用者確認每個修復操作。
    7. 生成 JSON 格式的檢測報告。

.PARAMETER WhatIf
    顯示腳本將執行的操作，但不實際執行它們。

.PARAMETER Confirm
    在執行每個修復操作之前提示使用者進行確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    編碼：UTF-8 with BOM

    此腳本應在管理員權限下運行。
    建議在運行前備份系統。
#>

#region 模塊初始化與配置

# 設置輸出編碼為 UTF-8 with BOM
$BOM = New-Object System.Text.UTF8Encoding $true
[Console]::OutputEncoding = $BOM
[Console]::InputEncoding = $BOM

# 載入共用函數和日誌模塊（使用安全的路徑處理）
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$CoreDir = Join-Path $ProjectRoot "Core"
$LoggerPath = Join-Path $CoreDir "Logger.ps1"
$UtilsPath = Join-Path $CoreDir "Utils.ps1"

# 檢查並載入 Logger.ps1
if (Test-Path $LoggerPath) {
    try {
        . $LoggerPath
        Write-Verbose "成功載入日誌模塊：$LoggerPath"
    }
    catch {
        Write-Warning "載入日誌模塊失敗：$($_.Exception.Message)"
        function Write-Log { 
            param([string]$Level = "INFO", [string]$Message) 
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Host "[$timestamp][$Level] $Message" 
        }
    }
} else {
    Write-Warning "找不到日誌模塊：$LoggerPath。使用內建日誌功能。"
    # 提供完整的內建日誌函數
    function Write-Log { 
        param([string]$Level = "INFO", [string]$Message) 
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARN"  { "Yellow" }
            "DEBUG" { "Gray" }
            default { "White" }
        }
        Write-Host "[$timestamp][$Level] $Message" -ForegroundColor $color
    }
}

# 檢查並載入 Utils.ps1
if (Test-Path $UtilsPath) {
    try {
        . $UtilsPath
        Write-Verbose "成功載入工具模塊：$UtilsPath"
    }
    catch {
        Write-Warning "載入工具模塊失敗：$($_.Exception.Message)"
        function Show-Progress { 
            param([string]$Activity, [string]$Status, [int]$PercentComplete) 
            Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete 
        }
    }
} else {
    Write-Warning "找不到工具模塊：$UtilsPath。使用內建功能。"
    # 提供基本的進度顯示函數
    function Show-Progress { 
        param([string]$Activity, [string]$Status, [int]$PercentComplete) 
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete 
    }
}

# 定義模塊名稱，用於日誌記錄和報告
$ModuleName = "H1_Environment_Variables"

#endregion

#region 函數定義

function Test-IsWritablePath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    Write-Log -Level "DEBUG" -Message "檢查路徑 '$Path' 是否可寫。"
    try {
        # 嘗試在該路徑下創建一個臨時文件
        $tempFile = Join-Path $Path "temp_write_test_$(Get-Random).tmp"
        Add-Content -Path $tempFile -Value "test" -ErrorAction Stop
        Remove-Item -Path $tempFile -ErrorAction Stop
        Write-Log -Level "DEBUG" -Message "路徑 '$Path' 可寫。"
        return $true
    }
    catch {
        Write-Log -Level "DEBUG" -Message "路徑 '$Path' 不可寫或發生錯誤：$($_.Exception.Message)"
        return $false
    }
}

function Get-EnvironmentVariableSecurityReport {
    [CmdletBinding()]
    param (
        [switch]$WhatIf,
        [switch]$Confirm
    )

    Write-Log -Level "INFO" -Message "[$ModuleName] 開始執行環境變數安全檢測。"
    Show-Progress -Activity "環境變數安全檢測" -Status "初始化..." -PercentComplete 0

    $Report = @{
        ModuleName = $ModuleName
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Status = "進行中"
        Findings = @()
        Remediations = @()
    }

    #region 檢測 PATH 環境變數
    Write-Log -Level "INFO" -Message "[$ModuleName] 檢測 PATH 環境變數..."
    Show-Progress -Activity "環境變數安全檢測" -Status "檢測 PATH 環境變數..." -PercentComplete 20

    $pathVariables = @(
        @{ Name = "System PATH"; Value = [System.Environment]::GetEnvironmentVariable("Path", "Machine") },
        @{ Name = "User PATH"; Value = [System.Environment]::GetEnvironmentVariable("Path", "User") }
    )

    foreach ($pv in $pathVariables) {
        $name = $pv.Name
        $value = $pv.Value
        Write-Log -Level "INFO" -Message "[$ModuleName] 正在分析 $name: $value"

        if ([string]::IsNullOrEmpty($value)) {
            $Report.Findings += @{
                Type = "Warning";
                Description = "$name 為空。";
                Details = "$name 環境變數未設置。";
                Severity = "Low"
            }
            continue
        }

        $paths = $value -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $uniquePaths = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

        foreach ($path in $paths) {
            $normalizedPath = $path.Trim()
            if ($uniquePaths.Contains($normalizedPath)) {
                $Report.Findings += @{
                    Type = "Warning";
                    Description = "$name 包含重複路徑: '$normalizedPath'.";
                    Details = "重複的路徑會增加 PATH 的長度，可能影響性能或引入混淆。";
                    Severity = "Low"
                }
                Write-Log -Level "WARNING" -Message "[$ModuleName] $name 包含重複路徑: '$normalizedPath'."
            } else {
                $uniquePaths.Add($normalizedPath)
            }

            if (-not (Test-Path $normalizedPath -PathType Container)) {
                $Report.Findings += @{
                    Type = "Warning";
                    Description = "$name 包含不存在的路徑: '$normalizedPath'.";
                    Details = "不存在的路徑可能導致命令執行失敗或被利用進行 PATH 劫持。";
                    Severity = "Medium"
                }
                Write-Log -Level "WARNING" -Message "[$ModuleName] $name 包含不存在的路徑: '$normalizedPath'."
            } else {
                # 檢查可寫目錄
                if (Test-IsWritablePath -Path $normalizedPath) {
                    $Report.Findings += @{
                        Type = "Critical";
                        Description = "$name 包含可寫的路徑: '$normalizedPath'.";
                        Details = "可寫的路徑可能被惡意軟體利用進行 DLL 劫持或執行任意代碼。";
                        Severity = "High"
                    }
                    Write-Log -Level "CRITICAL" -Message "[$ModuleName] $name 包含可寫的路徑: '$normalizedPath'."

                    # 建議修復：移除可疑路徑或修復權限
                    $Report.Remediations += @{
                        Action = "建議手動檢查或移除";
                        Target = "$name: '$normalizedPath'";
                        Description = "此路徑可寫，存在 DLL 劫持風險。請考慮移除此路徑或限制其寫入權限。";
                        Status = "待處理"
                    }
                }
            }
        }
    }
    #endregion

    #region 檢測 DLL 搜尋順序 (簡化檢測，主要依賴 PATH 檢測)
    Write-Log -Level "INFO" -Message "[$ModuleName] 檢測 DLL 搜尋順序相關設置..."
    Show-Progress -Activity "環境變數安全檢測" -Status "檢測 DLL 搜尋順序..." -PercentComplete 50

    # 檢查 NoDefaultCurrentDirectoryInExePath 註冊表項
    # 這是一個重要的安全設置，可以防止 DLL 預加載劫持
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SafeDllSearchMode"
    $safeDllSearchMode = Get-ItemProperty -Path $regPath -Name "SafeDllSearchMode" -ErrorAction SilentlyContinue

    if ($safeDllSearchMode -and $safeDllSearchMode.SafeDllSearchMode -eq 0) {
        $Report.Findings += @{
            Type = "Critical";
            Description = "SafeDllSearchMode 未啟用或設置不安全。";
            Details = "SafeDllSearchMode 應設置為 1 以啟用安全 DLL 搜尋模式，防止 DLL 預加載劫持。";
            Severity = "High"
        }
        Write-Log -Level "CRITICAL" -Message "[$ModuleName] SafeDllSearchMode 未啟用或設置不安全。"

        $Report.Remediations += @{
            Action = "建議啟用 SafeDllSearchMode";
            Target = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SafeDllSearchMode";
            Description = "將 SafeDllSearchMode 設置為 1。";
            Command = "Set-ItemProperty -Path '$regPath' -Name 'SafeDllSearchMode' -Value 1";
            Status = "待處理"
        }
    } else {
        Write-Log -Level "INFO" -Message "[$ModuleName] SafeDllSearchMode 已啟用或設置安全。"
    }

    # 檢查其他可能影響 DLL 搜尋順序的環境變數，例如 CPATH, LIBRARY_PATH (通常在開發環境中)
    $suspiciousDllEnvVars = @("CPATH", "LIBRARY_PATH", "LD_LIBRARY_PATH")
    foreach ($envVar in $suspiciousDllEnvVars) {
        $envValue = [System.Environment]::GetEnvironmentVariable($envVar, "Machine")
        if (-not [string]::IsNullOrEmpty($envValue)) {
            $Report.Findings += @{
                Type = "Warning";
                Description = "檢測到可疑的 DLL 相關環境變數 '$envVar'.";
                Details = "環境變數 '$envVar' (值: '$envValue') 可能影響 DLL 搜尋順序，應仔細審查。";
                Severity = "Medium"
            }
            Write-Log -Level "WARNING" -Message "[$ModuleName] 檢測到可疑的 DLL 相關環境變數 '$envVar'."
        }
    }
    #endregion

    #region 檢測其他可疑的環境變數
    Write-Log -Level "INFO" -Message "[$ModuleName] 檢測其他可疑的環境變數..."
    Show-Progress -Activity "環境變數安全檢測" -Status "檢測可疑環境變數..." -PercentComplete 80

    # 這裡可以添加更多針對特定惡意軟體或攻擊模式的環境變數檢測
    # 例如，檢查是否存在異常的 PROMPT, TEMP, TMP, COMSPEC 等變數被篡改
    $commonEnvVars = @("PROMPT", "TEMP", "TMP", "COMSPEC", "APPDATA", "LOCALAPPDATA", "PROGRAMDATA")
    foreach ($envVar in $commonEnvVars) {
        $machineValue = [System.Environment]::GetEnvironmentVariable($envVar, "Machine")
        $userValue = [System.Environment]::GetEnvironmentVariable($envVar, "User")

        # 這裡的邏輯需要根據具體威脅情報來判斷是否可疑
        # 簡單的檢查是看它們是否指向非標準路徑或包含可疑內容
        # 由於沒有具體的威脅情報，這裡只做存在性檢查和記錄
        if (-not [string]::IsNullOrEmpty($machineValue) -and $machineValue -notlike "C:\*" -and $machineValue -notlike "%*%") {
             $Report.Findings += @{
                Type = "Informational";
                Description = "系統環境變數 '$envVar' (值: '$machineValue') 可能非標準。";
                Details = "請檢查此環境變數是否被惡意修改。";
                Severity = "Low"
            }
            Write-Log -Level "INFO" -Message "[$ModuleName] 系統環境變數 '$envVar' (值: '$machineValue') 可能非標準。"
        }
        if (-not [string]::IsNullOrEmpty($userValue) -and $userValue -notlike "C:\*" -and $userValue -notlike "%*%") {
             $Report.Findings += @{
                Type = "Informational";
                Description = "使用者環境變數 '$envVar' (值: '$userValue') 可能非標準。";
                Details = "請檢查此環境變數是否被惡意修改。";
                Severity = "Low"
            }
            Write-Log -Level "INFO" -Message "[$ModuleName] 使用者環境變數 '$envVar' (值: '$userValue') 可能非標準。"
        }
    }
    #endregion

    $Report.Status = "完成"
    Write-Log -Level "INFO" -Message "[$ModuleName] 環境變數安全檢測完成。"
    Show-Progress -Activity "環境變數安全檢測" -Status "完成" -PercentComplete 100

    return $Report
}

function Invoke-EnvironmentVariableRemediation {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$RemediationItem
    )

    $action = $RemediationItem.Action
    $target = $RemediationItem.Target
    $description = $RemediationItem.Description
    $command = $RemediationItem.Command

    if ($PSCmdlet.ShouldProcess("目標: $target, 描述: $description", "執行修復操作: $action", "環境變數安全模塊")) {
        Write-Log -Level "INFO" -Message "[$ModuleName] 執行修復操作: $action - 目標: $target"
        try {
            if (-not [string]::IsNullOrEmpty($command)) {
                Invoke-Expression $command
                $RemediationItem.Status = "已執行"
                Write-Log -Level "INFO" -Message "[$ModuleName] 修復操作成功: $action - 目標: $target"
            } else {
                $RemediationItem.Status = "需手動處理"
                Write-Log -Level "WARNING" -Message "[$ModuleName] 修復操作 '$action' 需要手動處理，無自動命令。"
            }
        }
        catch {
            $RemediationItem.Status = "執行失敗"
            Write-Log -Level "ERROR" -Message "[$ModuleName] 修復操作失敗: $action - 目標: $target - 錯誤: $($_.Exception.Message)"
        }
    } else {
        $RemediationItem.Status = "已跳過"
        Write-Log -Level "INFO" -Message "[$ModuleName] 修復操作已跳過: $action - 目標: $target"
    }
    return $RemediationItem
}

#endregion

#region 主執行邏輯

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param (
    [switch]$WhatIf,
    [switch]$Confirm
)

# 確保以管理員權限運行
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log -Level "CRITICAL" -Message "[$ModuleName] 此腳本需要管理員權限才能運行。請以管理員身份重新啟動。"
    Write-Error "此腳本需要管理員權限。"
    exit 1
}

$detectionReport = Get-EnvironmentVariableSecurityReport -WhatIf:$WhatIf -Confirm:$Confirm

if ($detectionReport.Remediations.Count -gt 0) {
    Write-Log -Level "INFO" -Message "[$ModuleName] 檢測到 $($detectionReport.Remediations.Count) 個建議修復項目。"
    foreach ($remediation in $detectionReport.Remediations) {
        $updatedRemediation = Invoke-EnvironmentVariableRemediation -RemediationItem $remediation -WhatIf:$WhatIf -Confirm:$Confirm
        # 更新報告中的修復狀態
        $remediation.Status = $updatedRemediation.Status
    }
}

# 將報告轉換為 JSON 格式
$jsonReport = $detectionReport | ConvertTo-Json -Depth 100 -Compress

# 將 JSON 報告保存到文件
$reportFileName = "H1_Environment_Variables_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$reportPath = Join-Path (Join-Path $CoreDir "..\Reports") $reportFileName

# 確保 Reports 目錄存在
if (-not (Test-Path (Join-Path $CoreDir "..\Reports"))) {
    New-Item -Path (Join-Path $CoreDir "..\Reports") -ItemType Directory -Force | Out-Null
}

$jsonReport | Out-File -FilePath $reportPath -Encoding UTF8 -Force
Write-Log -Level "INFO" -Message "[$ModuleName] 檢測報告已保存至：$reportPath"

Write-Host "`n`n檢測報告已生成。請查看文件：$reportPath"

#endregion
```
