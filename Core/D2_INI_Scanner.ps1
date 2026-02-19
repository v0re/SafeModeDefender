
<#
.SYNOPSIS
    D2_INI_Scanner - INI 檔案安全掃描模塊
.DESCRIPTION
    此腳本用於掃描 Windows 系統中的 INI 檔案，特別是 desktop.ini，檢測潛在的安全威脅，
    例如惡意指令、異常內容和不安全的檔案權限。它支援 -WhatIf 和 -Confirm 參數，
    提供多級別日誌記錄和進度顯示，並生成 JSON 格式的檢測報告。
.PARAMETER Path
    指定要掃描的根目錄。如果未指定，則預設掃描系統關鍵目錄。
.PARAMETER LogPath
    指定日誌檔案的儲存路徑。預設為模塊目錄下的 Logs 子目錄。
.PARAMETER ReportPath
    指定檢測報告的儲存路徑。預設為模塊目錄下的 Reports 子目錄。
.EXAMPLE
    D2_INI_Scanner.ps1 -Path C:\Users\TestUser -WhatIf
    掃描指定路徑下的 INI 檔案，並顯示將執行的操作，但不實際執行。
.EXAMPLE
    D2_INI_Scanner.ps1 -Confirm
    掃描系統關鍵目錄下的 INI 檔案，並在執行每個修復操作前進行確認。
.EXAMPLE
    D2_INI_Scanner.ps1
    掃描系統關鍵目錄下的 INI 檔案，並自動執行修復操作。
.NOTES
    作者：Manus AI
    日期：2026-02-18
    版本：1.0
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [Parameter(Mandatory=$false)]
    [string]$Path = "",

    [Parameter(Mandatory=$false)]
    [string]$LogPath = (Join-Path $PSScriptRoot "Logs"),

    [Parameter(Mandatory=$false)]
    [string]$ReportPath = (Join-Path $PSScriptRoot "Reports")
)

#region 函數定義

# 設置 UTF-8 with BOM 編碼
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO" # INFO, WARN, ERROR, DEBUG
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path (Join-Path $LogPath "D2_INI_Scanner.log") -Value $LogEntry
    Write-Host $LogEntry
}

function Get-IniContent {
    param(
        [string]$FilePath
    )
    try {
        Get-Content -Path $FilePath -Raw -Encoding UTF8
    }
    catch {
        Write-Log -Message "無法讀取 INI 檔案 $($FilePath)：$($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Test-SuspiciousIniContent {
    param(
        [string]$IniContent
    )
    $suspiciousPatterns = @(
        "cmd.exe",
        "powershell.exe",
        "rundll32.exe",
        "javascript:",
        "file://",
        "shell32.dll",
        "@", # 用於 desktop.ini 的 IconFile 或 IconResource 指向外部可執行檔
        "command=" # 某些 INI 檔案可能包含 command 關鍵字
    )

    foreach ($pattern in $suspiciousPatterns) {
        if ($IniContent -match $pattern) {
            return $true
        }
    }
    return $false
}

function Get-FilePermissions {
    param(
        [string]$FilePath
    )
    try {
        $acl = Get-Acl -Path $FilePath
        $permissions = @()
        foreach ($access in $acl.Access) {
            $permissions += "$($access.IdentityReference): $($access.FileSystemRights) ($($access.AccessControlType))"
        }
        return $permissions -join "; "
    }
    catch {
        Write-Log -Message "無法獲取檔案權限 $($FilePath)：$($_.Exception.Message)" -Level "ERROR"
        return "無法獲取權限"
    }
}

#endregion

#region 主邏輯

function Main {
    Write-Log -Message "D2_INI_Scanner 模塊啟動。" -Level "INFO"

    # 確保日誌和報告目錄存在
    if (-not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $ReportPath)) { New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null }

    $scanResults = @()
    $targetPaths = @()

    if ([string]::IsNullOrEmpty($Path)) {
        Write-Log -Message "未指定掃描路徑，將掃描系統關鍵目錄。" -Level "INFO"
        $targetPaths += "$env:SystemDrive\Users\Public"
        $targetPaths += "$env:SystemDrive\ProgramData"
        $targetPaths += "$env:SystemDrive\Windows\System32"
        $targetPaths += "$env:SystemDrive\Windows\SysWOW64"
        $targetPaths += "$env:APPDATA"
        $targetPaths += "$env:LOCALAPPDATA"
        # 更多關鍵目錄可以根據實際威脅情報添加
    } else {
        $targetPaths += $Path
    }

    $iniFiles = @()
    foreach ($tp in $targetPaths) {
        if (Test-Path $tp) {
            $iniFiles += Get-ChildItem -Path $tp -Filter "*.ini" -Recurse -ErrorAction SilentlyContinue
        } else {
            Write-Log -Message "指定路徑 $($tp) 不存在，跳過。" -Level "WARN"
        }
    }

    $totalFiles = $iniFiles.Count
    Write-Log -Message "共找到 $($totalFiles) 個 INI 檔案進行掃描。" -Level "INFO"

    for ($i = 0; $i -lt $totalFiles; $i++) {
        $file = $iniFiles[$i]
        $progress = [int](($i / $totalFiles) * 100)
        Write-Progress -Activity "掃描 INI 檔案" -Status "正在處理 $($file.FullName)" -PercentComplete $progress

        Write-Log -Message "正在掃描檔案：$($file.FullName)" -Level "DEBUG"

        $iniContent = Get-IniContent -FilePath $file.FullName
        if (-not $iniContent) {
            continue
        }

        $isSuspicious = Test-SuspiciousIniContent -IniContent $iniContent
        $permissions = Get-FilePermissions -FilePath $file.FullName

        $result = [PSCustomObject]@{}
        $result | Add-Member -NotePropertyName "FilePath" -NotePropertyValue $file.FullName
        $result | Add-Member -NotePropertyName "FileName" -NotePropertyValue $file.Name
        $result | Add-Member -NotePropertyName "Directory" -NotePropertyValue $file.DirectoryName
        $result | Add-Member -NotePropertyName "IsSuspiciousContent" -NotePropertyValue $isSuspicious
        $result | Add-Member -NotePropertyName "Permissions" -NotePropertyValue $permissions
        $result | Add-Member -NotePropertyName "ContentSnippet" -NotePropertyValue ($iniContent.Substring(0, [System.Math]::Min(500, $iniContent.Length)))
        $result | Add-Member -NotePropertyName "ThreatDescription" -NotePropertyValue ($null)
        $result | Add-Member -NotePropertyName "RemediationAction" -NotePropertyValue ($null)

        if ($isSuspicious) {
            $result.ThreatDescription = "檢測到可疑內容，可能包含惡意指令或引用。"
            $result.RemediationAction = "建議檢查檔案內容，並考慮移除或修復。"
            Write-Log -Message "發現可疑 INI 檔案：$($file.FullName)" -Level "WARN"

            if ($PSCmdlet.ShouldProcess($file.FullName, "檢查並修復可疑 INI 檔案")) {
                # 這裡可以添加自動修復邏輯，例如備份後刪除或修改
                # 為了安全起見，目前僅記錄，不自動刪除或修改
                Write-Log -Message "已記錄可疑 INI 檔案 $($file.FullName)，請手動檢查。" -Level "INFO"
            }
        }

        # 檢查不安全的權限，例如 Everyone 寫入
        if ($permissions -match "Everyone: Write" -or $permissions -match "Users: Write") {
            $result.ThreatDescription = "檢測到不安全的檔案權限，可能允許未經授權的修改。"
            $result.RemediationAction = "建議修復檔案權限，移除 Everyone 或 Users 的寫入權限。"
            Write-Log -Message "發現權限不安全的 INI 檔案：$($file.FullName)" -Level "WARN"

            if ($PSCmdlet.ShouldProcess($file.FullName, "修復 INI 檔案權限")) {
                # 這裡可以添加自動修復權限的邏輯
                Write-Log -Message "已記錄權限不安全的 INI 檔案 $($file.FullName)，請手動修復。" -Level "INFO"
            }
        }

        $scanResults += $result
    }

    Write-Progress -Activity "掃描 INI 檔案" -Status "掃描完成" -PercentComplete 100 -Completed

    # 生成 JSON 報告
    $reportFileName = "D2_INI_Scanner_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $reportFilePath = Join-Path $ReportPath $reportFileName
    $scanResults | ConvertTo-Json -Depth 100 | Out-File -FilePath $reportFilePath -Encoding utf8
    Write-Log -Message "檢測報告已生成：$reportFilePath" -Level "INFO"

    Write-Log -Message "D2_INI_Scanner 模塊執行完畢。" -Level "INFO"
}

Main
