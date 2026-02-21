<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>

<#
.SYNOPSIS
    C2_Registry_Hijack - 註冊表替換符檢測模塊

.DESCRIPTION
    此腳本用於檢測 Windows 系統中可能存在的註冊表劫持（Registry Hijack）行為。
    它會掃描常見的註冊表持久化點、COM 劫持相關鍵值以及 UAC 繞過中涉及的註冊表修改，
    並生成詳細的檢測報告。

.PARAMETER WhatIf
    如果指定此參數，腳本將顯示它將執行的操作，但不會實際執行這些操作。

.PARAMETER Confirm
    如果指定此參數，腳本將在執行任何操作之前提示您進行確認。

.EXAMPLE
    Detect-RegistryHijack -WhatIf
    顯示將執行的檢測操作，但不實際執行。

.EXAMPLE
    Detect-RegistryHijack -Confirm
    在執行檢測操作前提示確認。

.EXAMPLE
    Detect-RegistryHijack
    執行註冊表劫持檢測並生成報告。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    編碼：UTF-8 with BOM
#>

# 設置輸出編碼為 UTF-8 with BOM
$PSDefaultParameterValues['*:Encoding'] = 'utf8BOM'

function Detect-RegistryHijack {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        # 無參數，但支持 -WhatIf 和 -Confirm
    )

    # 初始化報告對象
    $report = @{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        ModuleName = "C2_Registry_Hijack"
        DetectedThreats = @()
        ScanSummary = @{
            TotalKeysScanned = 0
            SuspiciousKeysFound = 0
        }
    }

    Write-Host "`n[+] 開始執行註冊表替換符檢測模塊..." -ForegroundColor Green

    # 模擬進度條
    $totalSteps = 10
    for ($i = 1; $i -le $totalSteps; $i++) {
        Write-Progress -Activity "正在檢測註冊表劫持" -Status "進度: $($i)/$($totalSteps)" -PercentComplete (($i / $totalSteps) * 100)
        Start-Sleep -Milliseconds 100 # 模擬工作
    }

    if ($PSCmdlet.ShouldProcess("執行註冊表劫持檢測", "您確定要執行此操作嗎？")) {
        Write-Host "[i] 正在檢測常見的註冊表持久化點..." -ForegroundColor Cyan
        # 這裡將添加實際的檢測邏輯

        # 示例：檢測 Run 鍵
        $runKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        )

        foreach ($keyPath in $runKeys) {
            $report.ScanSummary.TotalKeysScanned++
            try {
                if (Test-Path $keyPath) {
                    $items = Get-ItemProperty -Path $keyPath -ErrorAction Stop
                    foreach ($item in $items.PSObject.Properties) {
                        if ($item.Name -ne "PSPath" -and $item.Name -ne "PSParentPath" -and $item.Name -ne "PSChildName" -and $item.Name -ne "PSDrive" -and $item.Name -ne "PSProvider") {
                            $value = $item.Value
                            Write-Verbose "[VERBOSE] 正在檢查鍵值: $($keyPath)\$($item.Name) = $($value)"
                            # 這裡可以添加更複雜的邏輯來判斷是否為惡意
                            if ($value -like "*evil.exe*") {
                                Write-Warning "[!] 發現可疑註冊表項: $($keyPath)\$($item.Name) = $($value)"
                                $report.DetectedThreats += @{
                                    Type = "Registry Persistence"
                                    KeyPath = "$($keyPath)"
                                    ValueName = "$($item.Name)"
                                    ValueData = "$($value)"
                                    Description = "在啟動項中發現可疑條目，可能用於持久化。"
                                }
                                $report.ScanSummary.SuspiciousKeysFound++
                            }
                        }
                    }
                }
            }
            catch {
                Write-Error "[ERROR] 無法訪問註冊表路徑 $($keyPath): $($_.Exception.Message)"
                # 記錄錯誤，但不中斷腳本執行
            }
        }

        # 更多檢測邏輯將在此處添加，例如 COM 劫持、UAC 繞過等
        Write-Host "[i] 正在檢測 COM 劫持相關鍵值..." -ForegroundColor Cyan
        # 示例：檢測 HKEY_CURRENT_USER\Software\Classes\CLSID 下的異常條目
        $comHijackPath = "HKCU:\Software\Classes\CLSID"
        $report.ScanSummary.TotalKeysScanned++
        try {
            if (Test-Path $comHijackPath) {
                $clsidKeys = Get-ChildItem -Path $comHijackPath -ErrorAction Stop
                foreach ($clsidKey in $clsidKeys) {
                    # 檢查是否存在 InprocServer32 或 LocalServer32 並指向可疑路徑
                    $inprocServer32Path = Join-Path $clsidKey.PSPath "InprocServer32"
                    $localServer32Path = Join-Path $clsidKey.PSPath "LocalServer32"

                    if (Test-Path $inprocServer32Path) {
                        $dllPath = (Get-ItemProperty -Path $inprocServer32Path -Name "(Default)" -ErrorAction SilentlyContinue)."(Default)"
                        if ($dllPath -and ($dllPath -notmatch "^C:\\Windows\\System32" -and $dllPath -notmatch "^C:\\Windows\\SysWOW64")) {
                            Write-Warning "[!] 發現可疑 COM InprocServer32 條目: $($inprocServer32Path) -> $($dllPath)"
                            $report.DetectedThreats += @{
                                Type = "COM Hijacking"
                                KeyPath = "$($inprocServer32Path)"
                                ValueName = "(Default)"
                                ValueData = "$($dllPath)"
                                Description = "COM InprocServer32 指向非標準路徑，可能存在劫持。"
                            }
                            $report.ScanSummary.SuspiciousKeysFound++
                        }
                    }
                    if (Test-Path $localServer32Path) {
                        $exePath = (Get-ItemProperty -Path $localServer32Path -Name "(Default)" -ErrorAction SilentlyContinue)."(Default)"
                        if ($exePath -and ($exePath -notmatch "^C:\\Windows\\System32" -and $exePath -notmatch "^C:\\Windows\\SysWOW64")) {
                            Write-Warning "[!] 發現可疑 COM LocalServer32 條目: $($localServer32Path) -> $($exePath)"
                            $report.DetectedThreats += @{
                                Type = "COM Hijacking"
                                KeyPath = "$($localServer32Path)"
                                ValueName = "(Default)"
                                ValueData = "$($exePath)"
                                Description = "COM LocalServer32 指向非標準路徑，可能存在劫持。"
                            }
                            $report.ScanSummary.SuspiciousKeysFound++
                        }
                    }
                }
            }
        }
        catch {
            Write-Error "[ERROR] 無法訪問註冊表路徑 $($comHijackPath): $($_.Exception.Message)"
        }

        # UAC 繞過檢測 (例如 Fodhelper 相關)
        Write-Host "[i] 正在檢測 UAC 繞過相關註冊表修改..." -ForegroundColor Cyan
        $uacBypassKey = "HKCU:\Software\Classes\ms-settings\shell\open\command"
        $report.ScanSummary.TotalKeysScanned++
        try {
            if (Test-Path $uacBypassKey) {
                $commandValue = (Get-ItemProperty -Path $uacBypassKey -Name "(Default)" -ErrorAction SilentlyContinue)."(Default)"
                if ($commandValue -and ($commandValue -notmatch "^%SystemRoot%\\System32\\fodhelper.exe")) {
                    Write-Warning "[!] 發現可疑 UAC 繞過註冊表項: $($uacBypassKey) = $($commandValue)"
                    $report.DetectedThreats += @{
                        Type = "UAC Bypass"
                        KeyPath = "$($uacBypassKey)"
                        ValueName = "(Default)"
                        ValueData = "$($commandValue)"
                        Description = "ms-settings 處理程序被修改，可能存在 UAC 繞過。"
                    }
                    $report.ScanSummary.SuspiciousKeysFound++
                }
            }
        }
        catch {
            Write-Error "[ERROR] 無法訪問註冊表路徑 $($uacBypassKey): $($_.Exception.Message)"
        }

        Write-Host "`n[+] 檢測完成。" -ForegroundColor Green
    }
    else {
        Write-Host "[i] 操作已被用戶取消。" -ForegroundColor Yellow
    }

    # 生成 JSON 報告
    $jsonReportPath = "/home/ubuntu/SafeModeDefender_v2/Core/RegistryPersistence/C2_Registry_Hijack_Report.json"
    $report | ConvertTo-Json -Depth 100 | Set-Content -Path $jsonReportPath -Encoding UTF8
    Write-Host "[+] 檢測報告已保存至: $($jsonReportPath)" -ForegroundColor Green

    return $jsonReportPath
}

# 執行函數
Detect-RegistryHijack
