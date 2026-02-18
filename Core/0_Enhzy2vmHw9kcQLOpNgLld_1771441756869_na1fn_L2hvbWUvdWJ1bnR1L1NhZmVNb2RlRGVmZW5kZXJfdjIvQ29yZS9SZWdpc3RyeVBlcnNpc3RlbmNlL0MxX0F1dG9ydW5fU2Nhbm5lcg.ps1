#region Script Header
<#
.SYNOPSIS
    C1_Autorun_Scanner - 註冊表自啟動項全面掃描模塊

.DESCRIPTION
    此 PowerShell 腳本用於全面掃描 Windows 註冊表中的自啟動項，檢測潛在的惡意或可疑啟動程序。
    它會檢查多個關鍵註冊表路徑，驗證執行檔路徑和數位簽章，並生成詳細的 JSON 格式檢測報告。
    腳本支援 -WhatIf 和 -Confirm 參數，提供多級別日誌記錄和進度顯示。

.PARAMETER WhatIf
    顯示如果執行命令會發生什麼，但不實際執行命令。

.PARAMETER Confirm
    在執行命令前提示您進行確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    要求：Windows PowerShell 5.1 或更高版本

.EXAMPLE
    .\C1_Autorun_Scanner.ps1
    掃描所有自啟動項並生成報告。

.EXAMPLE
    .\C1_Autorun_Scanner.ps1 -WhatIf
    顯示將要執行的操作，但不實際修改系統。

.EXAMPLE
    .\C1_Autorun_Scanner.ps1 -Confirm
    在執行任何修改操作前提示用戶確認。

.EXAMPLE
    .\C1_Autorun_Scanner.ps1 -Verbose
    以詳細模式運行，顯示更多日誌信息。
#>

# 設定輸出編碼為 UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

#region 函數定義

Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('INFO','WARNING','ERROR','DEBUG')]
        [string]$Level,

        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"

    # 根據日誌級別輸出到控制台
    switch ($Level) {
        "INFO" { Write-Host -ForegroundColor Green $LogEntry }
        "WARNING" { Write-Warning $LogEntry }
        "ERROR" { Write-Error $LogEntry }
        "DEBUG" { if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose')) { Write-Host -ForegroundColor DarkGray $LogEntry } }
    }

    # 這裡可以添加將日誌寫入文件的邏輯
    # 例如：Add-Content -Path $LogFilePath -Value $LogEntry
}

Function Get-DigitalSignatureStatus {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Write-Log -Level DEBUG -Message "檔案不存在，無法檢查數位簽章: $FilePath"
        return "檔案不存在"
    }

    try {
        $signature = Get-AuthenticodeSignature -FilePath $FilePath
        if ($signature.Status -eq "Valid") {
            return "有效"
        } elseif ($signature.Status -eq "NotSigned") {
            return "未簽名"
        } else {
            return "無效 ($($signature.Status))"
        }
    }
    catch {
        Write-Log -Level ERROR -Message "檢查數位簽章時發生錯誤: $($_.Exception.Message)"
        return "錯誤"
    }
}

#endregion

#region 主要邏輯

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param()

Write-Log -Level INFO -Message "C1_Autorun_Scanner 模塊啟動，開始掃描註冊表自啟動項..."

$Report = @{
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Module = "C1_Autorun_Scanner"
    Description = "註冊表自啟動項全面掃描報告"
    ScanResults = @()
}

$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders",
    "HKLM:\SYSTEM\CurrentControlSet\Services", # 需要進一步處理 ImagePath
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" # 需要進一步處理 Shell, Userinit
)

$TotalPaths = $RegistryPaths.Count
$CurrentPathIndex = 0

foreach ($Path in $RegistryPaths) {
    $CurrentPathIndex++
    Write-Progress -Activity "掃描註冊表自啟動項" -Status "正在檢查: $Path" -PercentComplete (($CurrentPathIndex / $TotalPaths) * 100)
    Write-Log -Level INFO -Message "正在掃描註冊表路徑: $Path"

    try {
        # 處理 HKLM:\SYSTEM\CurrentControlSet\Services 路徑
        if ($Path -eq "HKLM:\SYSTEM\CurrentControlSet\Services") {
            Get-ChildItem -Path $Path -ErrorAction Stop | ForEach-Object {
                $ServicePath = $_.PSPath
                $ImagePath = (Get-ItemProperty -Path $ServicePath -Name ImagePath -ErrorAction SilentlyContinue).ImagePath
                if ($ImagePath) {
                    # 清理 ImagePath，移除引號和參數
                    $ExecutablePath = $ImagePath -replace '"' -split ' ' | Select-Object -First 1
                    $ExecutablePath = (Resolve-Path $ExecutablePath -ErrorAction SilentlyContinue).Path

                    $SignatureStatus = Get-DigitalSignatureStatus -FilePath $ExecutablePath
                    $Report.ScanResults += [PSCustomObject]@{ 
                        RegistryPath = $ServicePath;
                        Name = $_.PSChildName;
                        Value = $ImagePath;
                        ExecutablePath = $ExecutablePath;
                        DigitalSignature = $SignatureStatus;
                        Status = if ($SignatureStatus -eq "未簽名") {"可疑"} else {"正常"}
                    }
                    Write-Log -Level DEBUG -Message "發現服務啟動項: $($_.PSChildName), 路徑: $ExecutablePath, 簽章: $SignatureStatus"
                }
            }
        }
        # 處理 HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon 路徑
        elseif ($Path -eq "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon") {
            $WinlogonKeys = Get-ItemProperty -Path $Path -ErrorAction Stop | Select-Object -ExpandProperty PSObject.Properties | Where-Object {$_.Name -eq "Shell" -or $_.Name -eq "Userinit"}
            foreach ($Key in $WinlogonKeys) {
                $ExecutablePaths = $Key.Value -split ',' | ForEach-Object { $_.Trim() }
                foreach ($ExecutablePath in $ExecutablePaths) {
                    # 清理 ExecutablePath，移除引號和參數
                    $CleanPath = $ExecutablePath -replace '"' -split ' ' | Select-Object -First 1
                    $CleanPath = (Resolve-Path $CleanPath -ErrorAction SilentlyContinue).Path

                    $SignatureStatus = Get-DigitalSignatureStatus -FilePath $CleanPath
                    $Report.ScanResults += [PSCustomObject]@{ 
                        RegistryPath = $Path;
                        Name = $Key.Name;
                        Value = $ExecutablePath;
                        ExecutablePath = $CleanPath;
                        DigitalSignature = $SignatureStatus;
                        Status = if ($SignatureStatus -eq "未簽名") {"可疑"} else {"正常"}
                    }
                    Write-Log -Level DEBUG -Message "發現 Winlogon 啟動項: $($Key.Name), 路徑: $CleanPath, 簽章: $SignatureStatus"
                }
            }
        }
        # 處理其他 Run/RunOnce 類型的路徑
        else {
            Get-ItemProperty -Path $Path -ErrorAction Stop | ForEach-Object {
                $EntryName = $_.PSChildName
                $EntryValue = $_.PSObject.Properties | Where-Object {$_.Name -ne "PSPath" -and $_.Name -ne "PSParentPath" -and $_.Name -ne "PSChildName" -and $_.Name -ne "PSDrive" -and $_.Name -ne "PSProvider"} | Select-Object -ExpandProperty Value

                if ($EntryValue) {
                    # 清理 EntryValue，移除引號和參數
                    $ExecutablePath = $EntryValue -replace '"' -split ' ' | Select-Object -First 1
                    $ExecutablePath = (Resolve-Path $ExecutablePath -ErrorAction SilentlyContinue).Path

                    $SignatureStatus = Get-DigitalSignatureStatus -FilePath $ExecutablePath
                    $Report.ScanResults += [PSCustomObject]@{ 
                        RegistryPath = $Path;
                        Name = $EntryName;
                        Value = $EntryValue;
                        ExecutablePath = $ExecutablePath;
                        DigitalSignature = $SignatureStatus;
                        Status = if ($SignatureStatus -eq "未簽名") {"可疑"} else {"正常"}
                    }
                    Write-Log -Level DEBUG -Message "發現自啟動項: $EntryName, 路徑: $ExecutablePath, 簽章: $SignatureStatus"
                }
            }
        }
    }
    catch {
        Write-Log -Level ERROR -Message "掃描註冊表路徑 $Path 時發生錯誤: $($_.Exception.Message)"
    }
}

Write-Progress -Activity "掃描註冊表自啟動項" -Status "掃描完成" -PercentComplete 100 -Completed
Write-Log -Level INFO -Message "註冊表自啟動項掃描完成。"

# 生成 JSON 報告
$ReportJson = $Report | ConvertTo-Json -Depth 100 -Compress
$ReportFilePath = "$PSScriptRoot\C1_Autorun_Scanner_Report.json"

if ($PSCmdlet.ShouldProcess("生成檢測報告", "您確定要生成 JSON 格式的檢測報告嗎？")) {
    try {
        $ReportJson | Set-Content -Path $ReportFilePath -Encoding UTF8 -Force
        Write-Log -Level INFO -Message "檢測報告已保存至: $ReportFilePath"
    }
    catch {
        Write-Log -Level ERROR -Message "保存檢測報告時發生錯誤: $($_.Exception.Message)"
    }
}

#endregion

#region 回滾機制示例 (僅為示例，實際回滾邏輯需根據修復操作實現)
<#
Function Restore-RegistryBackup {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$BackupFilePath
    )

    if ($PSCmdlet.ShouldProcess("恢復註冊表備份", "您確定要從 $BackupFilePath 恢復註冊表嗎？這將覆蓋當前註冊表設置。")) {
        Write-Log -Level INFO -Message "正在從 $BackupFilePath 恢復註冊表備份..."
        # 實際的註冊表恢復邏輯，例如使用 reg import 命令
        # Start-Process -FilePath "reg.exe" -ArgumentList "import", "`"$BackupFilePath`"" -Wait -NoNewWindow
        Write-Log -Level INFO -Message "註冊表備份恢復完成。"
    }
}

# 在執行任何修改操作前，可以調用備份函數
# if ($PSCmdlet.ShouldProcess("備份註冊表", "您確定要備份當前註冊表狀態嗎？")) {
#     $BackupPath = "$PSScriptRoot\RegistryBackup_$(Get-Date -Format "yyyyMMddHHmmss").reg"
#     Write-Log -Level INFO -Message "正在備份註冊表至 $BackupPath..."
#     # 實際的註冊表備份邏輯，例如使用 reg export 命令
#     # Start-Process -FilePath "reg.exe" -ArgumentList "export", "HKLM", "`"$BackupPath`"", "/y" -Wait -NoNewWindow
#     Write-Log -Level INFO -Message "註冊表備份完成。"
# }
#>
#endregion
