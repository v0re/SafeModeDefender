<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>

<#
.SYNOPSIS
    D3_File_Permissions - 檔案權限異常檢測模塊
.DESCRIPTION
    此腳本用於檢測 Windows 系統中檔案和目錄的權限異常，並生成 JSON 格式的報告。
    它支援 -WhatIf 和 -Confirm 參數，提供多級別日誌記錄和進度顯示。
.PARAMETER Path
    指定要檢測的檔案或目錄路徑。如果未指定，則檢測預設的關鍵系統目錄。
.EXAMPLE
    Detect-FilePermissionAnomaly -Path "C:\Program Files"
.EXAMPLE
    Detect-FilePermissionAnomaly -WhatIf
.EXAMPLE
    Detect-FilePermissionAnomaly -Confirm
.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
#>

# 設置 UTF-8 with BOM 編碼
$PSDefaultParameterValues["*:Encoding"] = [System.Text.UTF8Encoding]::new($true)

function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level,

        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"

    # 根據日誌級別輸出到控制台，實際應用中可寫入檔案
    switch ($Level) {
        "INFO"  { Write-Host -ForegroundColor Green $LogEntry }
        "WARN"  { Write-Host -ForegroundColor Yellow $LogEntry }
        "ERROR" { Write-Host -ForegroundColor Red $LogEntry }
        "DEBUG" { Write-Host -ForegroundColor Cyan $LogEntry }
    }
}

function Detect-FilePermissionAnomaly {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact=\'High\')]
    Param(
        [Parameter(Position=0)]
        [string]$Path = "C:\"
    )

    # 初始化報告列表
    $Report = @()

    Write-Log -Level INFO -Message "開始檢測檔案權限異常，目標路徑：$Path"

    if ($PSCmdlet.ShouldProcess("路徑 \'$Path\'", "是否執行檔案權限異常檢測？")) {
        try {
            # 獲取指定路徑下的所有檔案和目錄
            $Items = Get-ChildItem -Path $Path -Recurse -ErrorAction Stop
            $TotalItems = $Items.Count
            $CurrentItem = 0

            foreach ($Item in $Items) {
                $CurrentItem++
                Write-Progress -Activity "檢測檔案權限" -Status "正在處理 $($Item.FullName)" -PercentComplete (($CurrentItem / $TotalItems) * 100)

                # 獲取檔案或目錄的 ACL
                $Acl = Get-Acl -Path $Item.FullName -ErrorAction SilentlyContinue

                if ($Acl) {
                    # 檢查 ACL 中的每個訪問規則
                    foreach ($Access in $Acl.Access) {
                        # 這裡可以添加權限異常的判斷邏輯
                        # 示例：檢查是否有 Everyone 具有 FullControl 權限
                        if ($Access.IdentityReference -eq "Everyone" -and $Access.FileSystemRights -match "FullControl") {
                            $ReportEntry = [PSCustomObject]@{ 
                                Path = $Item.FullName;
                                Identity = $Access.IdentityReference.Value;
                                Rights = $Access.FileSystemRights.ToString();
                                AccessControlType = $Access.AccessControlType.ToString();
                                IsPotentiallyMalicious = $true;
                                AnomalyDescription = "Everyone 具有 FullControl 權限，存在潛在風險。"
                            }
                            $Report += $ReportEntry
                            Write-Log -Level WARN -Message "發現潛在權限異常：$($Item.FullName) - $($Access.IdentityReference.Value) 具有 $($Access.FileSystemRights) 權限"
                        }
                        # 更多異常判斷邏輯可以添加到這裡
                    }
                } else {
                    Write-Log -Level WARN -Message "無法獲取 $($Item.FullName) 的 ACL，可能沒有權限或路徑不存在。"
                }
            }

            Write-Log -Level INFO -Message "檔案權限異常檢測完成。"

            # 將報告轉換為 JSON 格式
            $Report | ConvertTo-Json -Depth 100 | Out-File -FilePath "$PSScriptRoot\D3_File_Permissions_Report.json" -Encoding UTF8
            Write-Log -Level INFO -Message "檢測報告已保存至 $PSScriptRoot\D3_File_Permissions_Report.json"

        } catch {
            Write-Log -Level ERROR -Message "檢測過程中發生錯誤：$($_.Exception.Message)"
            throw $_.Exception
        }
    }
}

# 僅當腳本直接運行時執行
if ($MyInvocation.MyCommand.CommandType -eq "Function") {
    # 如果作為模塊導入，則不自動執行
} else {
    # 預設執行，可以根據需要添加參數
    Detect-FilePermissionAnomaly
}
