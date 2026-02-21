<#
.SYNOPSIS
    H2_Hosts_File - Hosts 檔案安全檢測模塊
    此腳本用於檢測 Windows 系統中的 Hosts 檔案是否被惡意修改，並提供修復選項。

.DESCRIPTION
    本 PowerShell 腳本旨在增強 Windows 系統的安全性，透過檢查 Hosts 檔案的完整性、權限和內容，
    以防止惡意軟體劫持網路流量或重定向到惡意網站。它支援詳細的日誌記錄、進度顯示、
    -WhatIf 和 -Confirm 參數，並能生成 JSON 格式的檢測報告。

.PARAMETER WhatIf
    顯示如果執行命令會發生什麼，但不實際執行命令。

.PARAMETER Confirm
    在執行命令前提示您進行確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026年2月18日
    編碼：UTF-8 with BOM
#>

#region 模塊參數
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param
(
    [switch]$WhatIf,
    [switch]$Confirm
)
#endregion

#region 函數定義

# 設置日誌函數
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'INFO' # INFO, WARN, ERROR, DEBUG
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"
    Write-Host $LogEntry
    # 實際應用中可將日誌寫入檔案
}

# 獲取 Hosts 檔案路徑
function Get-HostsFilePath {
    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    if (-not (Test-Path $hostsPath)) {
        Write-Log -Message "Hosts 檔案不存在於預期路徑: $hostsPath" -Level 'ERROR'
        throw "Hosts 檔案不存在。"
    }
    return $hostsPath
}

# 備份 Hosts 檔案
function Backup-HostsFile {
    param(
        [string]$HostsFilePath
    )
    $backupDir = Join-Path (Split-Path $HostsFilePath) "HostsBackup"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -ErrorAction Stop | Out-Null
    }
    $backupFileName = "hosts_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
    $backupPath = Join-Path $backupDir $backupFileName

    Write-Log -Message "正在備份 Hosts 檔案至 $backupPath ..." -Level 'INFO'
    try {
        Copy-Item -Path $HostsFilePath -Destination $backupPath -Force -ErrorAction Stop
        Write-Log -Message "Hosts 檔案備份成功。" -Level 'INFO'
        return $backupPath
    }
    catch {
        Write-Log -Message "備份 Hosts 檔案失敗: $($_.Exception.Message)" -Level 'ERROR'
        throw "備份失敗。"
    }
}

# 檢查 Hosts 檔案權限
function Test-HostsFilePermissions {
    param(
        [string]$HostsFilePath
    )
    Write-Log -Message "正在檢查 Hosts 檔案權限..." -Level 'INFO'
    $acl = Get-Acl -Path $HostsFilePath -ErrorAction Stop
    $report = @{
        'Status' = 'OK'
        'Details' = 'Hosts 檔案權限正常。'
        'Permissions' = @()
    }

    # 檢查是否只有 Administrators 和 SYSTEM 擁有寫入權限
    $hasVulnerableWritePermission = $false
    foreach ($access in $acl.Access) {
        $identity = $access.IdentityReference.Value
        $fileSystemRights = $access.FileSystemRights.ToString()
        $accessControlType = $access.AccessControlType.ToString()

        $permissionEntry = @{
            'Identity' = $identity
            'Rights' = $fileSystemRights
            'Type' = $accessControlType
        }
        $report.Permissions += $permissionEntry

        # 判斷是否有非 Administrators 或 SYSTEM 的使用者擁有寫入權限
        if ($accessControlType -eq 'Allow' -and ($fileSystemRights -like '*Write*' -or $fileSystemRights -like '*Modify*')) {
            if ($identity -notlike '*\Administrators' -and $identity -notlike '*\SYSTEM') {
                $hasVulnerableWritePermission = $true
                $report.Status = 'VULNERABLE'
                $report.Details = '發現非 Administrators 或 SYSTEM 的使用者擁有寫入權限。'
                break
            }
        }
    }

    if ($hasVulnerableWritePermission) {
        Write-Log -Message $report.Details -Level 'WARN'
    } else {
        Write-Log -Message $report.Details -Level 'INFO'
    }
    return $report
}

# 修復 Hosts 檔案權限
function Repair-HostsFilePermissions {
    param(
        [string]$HostsFilePath
    )
    if ($PSCmdlet.ShouldProcess("修復 Hosts 檔案權限", "您確定要將 Hosts 檔案權限重置為安全預設值嗎？")) {
        Write-Log -Message "正在修復 Hosts 檔案權限..." -Level 'INFO'
        try {
            # 創建新的 ACL 物件
            $acl = Get-Acl $HostsFilePath
            $acl.SetAccessRuleProtection($true, $false) # 禁用繼承，並移除所有現有權限

            # 定義安全權限
            $administratorsRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                "BUILTIN\Administrators", "FullControl", "Allow"
            )
            $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                "NT AUTHORITY\SYSTEM", "FullControl", "Allow"
            )
            $usersRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                "BUILTIN\Users", "ReadAndExecute, Synchronize", "Allow"
            )

            # 添加權限規則
            $acl.AddAccessRule($administratorsRule)
            $acl.AddAccessRule($systemRule)
            $acl.AddAccessRule($usersRule)

            # 應用新的 ACL
            Set-Acl -Path $HostsFilePath -AclObject $acl -ErrorAction Stop
            Write-Log -Message "Hosts 檔案權限修復成功。" -Level 'INFO'
            return $true
        }
        catch {
            Write-Log -Message "修復 Hosts 檔案權限失敗: $($_.Exception.Message)" -Level 'ERROR'
            return $false
        }
    }
    return $false
}

# 檢查 Hosts 檔案內容
function Test-HostsFileContent {
    param(
        [string]$HostsFilePath
    )
    Write-Log -Message "正在檢查 Hosts 檔案內容..." -Level 'INFO'
    $content = Get-Content -Path $HostsFilePath -Raw -Encoding UTF8 -ErrorAction Stop
    $report = @{
        'Status' = 'OK'
        'Details' = 'Hosts 檔案內容正常。'
        'MaliciousEntries' = @()
    }

    # 簡單的惡意條目檢測示例：指向 127.0.0.1 或 0.0.0.0 的可疑域名
    # 實際應用中需要更複雜的惡意域名列表或行為分析
    $maliciousPatterns = @(
        "^\s*(127\.0\.0\.1|0\.0\.0\.0)\s+(facebook\.com|google\.com|youtube\.com|microsoft\.com)"
        # 添加更多已知惡意或被劫持的域名模式
    )

    foreach ($line in $content -split "`n") {
        foreach ($pattern in $maliciousPatterns) {
            if ($line -match $pattern) {
                $report.Status = 'VULNERABLE'
                $report.Details = '發現潛在的惡意 Hosts 檔案條目。'
                $report.MaliciousEntries += $line.Trim()
            }
        }
    }

    if ($report.MaliciousEntries.Count -gt 0) {
        Write-Log -Message $report.Details -Level 'WARN'
        $report.MaliciousEntries | ForEach-Object { Write-Log -Message "惡意條目: $_" -Level 'WARN' }
    } else {
        Write-Log -Message $report.Details -Level 'INFO'
    }
    return $report
}

#endregion

#region 主執行邏輯
function Invoke-HostsFileSecurityCheck {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param()

    $overallReport = @{
        'Module' = 'H2_Hosts_File'
        'Timestamp' = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        'HostsFilePath' = ''
        'BackupPath' = ''
        'PermissionsCheck' = @{}
        'ContentCheck' = @{}
        'OverallStatus' = 'UNKNOWN'
        'Messages' = @()
    }

    try {
        Write-Log -Message "開始執行 Hosts 檔案安全檢測模塊..." -Level 'INFO'
        $overallReport.Messages += "開始執行 Hosts 檔案安全檢測模塊..."

        # 1. 獲取 Hosts 檔案路徑
        $hostsFilePath = Get-HostsFilePath
        $overallReport.HostsFilePath = $hostsFilePath
        Write-Progress -Activity "Hosts 檔案安全檢測" -Status "獲取 Hosts 檔案路徑" -PercentComplete 10

        # 2. 備份 Hosts 檔案
        $backupPath = Backup-HostsFile -HostsFilePath $hostsFilePath
        $overallReport.BackupPath = $backupPath
        Write-Progress -Activity "Hosts 檔案安全檢測" -Status "備份 Hosts 檔案" -PercentComplete 30

        # 3. 檢查 Hosts 檔案權限
        $permissionsReport = Test-HostsFilePermissions -HostsFilePath $hostsFilePath
        $overallReport.PermissionsCheck = $permissionsReport
        Write-Progress -Activity "Hosts 檔案安全檢測" -Status "檢查 Hosts 檔案權限" -PercentComplete 60

        # 如果權限有問題，提供修復選項
        if ($permissionsReport.Status -eq 'VULNERABLE') {
            Write-Log -Message "Hosts 檔案權限存在安全風險。" -Level 'WARN'
            $overallReport.Messages += "Hosts 檔案權限存在安全風險。"
            if ($PSCmdlet.ShouldProcess("修復 Hosts 檔案權限", "檢測到 Hosts 檔案權限存在安全風險，是否立即修復？")) {
                if (Repair-HostsFilePermissions -HostsFilePath $hostsFilePath) {
                    $overallReport.Messages += "Hosts 檔案權限已修復。"
                } else {
                    $overallReport.Messages += "Hosts 檔案權限修復失敗。"
                }
            }
        }

        # 4. 檢查 Hosts 檔案內容
        $contentReport = Test-HostsFileContent -HostsFilePath $hostsFilePath
        $overallReport.ContentCheck = $contentReport
        Write-Progress -Activity "Hosts 檔案安全檢測" -Status "檢查 Hosts 檔案內容" -PercentComplete 90

        # 判斷整體狀態
        if ($permissionsReport.Status -eq 'VULNERABLE' -or $contentReport.Status -eq 'VULNERABLE') {
            $overallReport.OverallStatus = 'VULNERABLE'
            Write-Log -Message "Hosts 檔案存在安全風險，請檢查報告。" -Level 'WARN'
            $overallReport.Messages += "Hosts 檔案存在安全風險，請檢查報告。"
        } else {
            $overallReport.OverallStatus = 'SECURE'
            Write-Log -Message "Hosts 檔案安全檢測完成，未發現明顯風險。" -Level 'INFO'
            $overallReport.Messages += "Hosts 檔案安全檢測完成，未發現明顯風險。"
        }

    }
    catch {
        Write-Log -Message "執行 Hosts 檔案安全檢測時發生錯誤: $($_.Exception.Message)" -Level 'ERROR'
        $overallReport.OverallStatus = 'ERROR'
        $overallReport.Messages += "執行 Hosts 檔案安全檢測時發生錯誤: $($_.Exception.Message)"
    }
    finally {
        Write-Progress -Activity "Hosts 檔案安全檢測" -Status "完成" -PercentComplete 100 -Completed
        # 輸出 JSON 格式報告
        $jsonReport = $overallReport | ConvertTo-Json -Depth 100 -Compress
        Write-Host "`n--- 檢測報告 (JSON) ---"`n"
        Write-Host $jsonReport
        $overallReport.Messages += "檢測報告已生成。"
    }
}

# 執行主邏輯
Invoke-HostsFileSecurityCheck

#endregion
