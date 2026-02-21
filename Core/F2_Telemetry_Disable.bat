<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>
# encoding: utf-8-with-bom
# F2_Telemetry_Disable - Windows 遙測與診斷禁用模塊

<#
.SYNOPSIS
    禁用 Windows 遙測與診斷功能，以增強使用者隱私。

.DESCRIPTION
    此腳本旨在禁用 Windows 作業系統中的遙測與診斷服務和設定，
    從而減少資料收集並提升系統隱私。它會修改相關的登錄檔鍵值、
    停止並禁用服務，並提供回滾機制。

.PARAMETER WhatIf
    描述在不實際執行操作的情況下，腳本將會做什麼。

.PARAMETER Confirm
    在執行任何修改操作之前，提示使用者進行確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    要求：Windows 10 或更高版本，以管理員權限執行。
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param
(
    [switch]$WhatIf,
    [switch]$Confirm
)

# 全局變數
$LogFilePath = "$PSScriptRoot\F2_Telemetry_Disable.log"
$ReportFilePath = "$PSScriptRoot\F2_Telemetry_Disable_Report.json"
$OriginalSettings = @{}

# 函數：設定日誌記錄
function Set-LogConfiguration {
    param (
        [string]$Path = $LogFilePath
    )
    $script:LogFilePath = $Path
    if (-not (Test-Path (Split-Path $script:LogFilePath))) {
        New-Item -ItemType Directory -Path (Split-Path $script:LogFilePath) -Force | Out-Null
    }
}

# 函數：記錄訊息
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [ValidateSet("Host", "File", "All")][string]$OutputTarget = "All"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"

    if ($OutputTarget -eq "Host" -or $OutputTarget -eq "All") {
        switch ($Level) {
            "INFO" { Write-Host -ForegroundColor Green $LogEntry }
            "WARN" { Write-Host -ForegroundColor Yellow $LogEntry }
            "ERROR" { Write-Host -ForegroundColor Red $LogEntry }
            "DEBUG" { Write-Host -ForegroundColor Cyan $LogEntry }
            default { Write-Host $LogEntry }
        }
    }
    if ($OutputTarget -eq "File" -or $OutputTarget -eq "All") {
        Add-Content -Path $script:LogFilePath -Value $LogEntry
    }
}

# 函數：顯示進度
function Show-Progress {
    param (
        [int]$Current,
        [int]$Total,
        [string]$Activity,
        [string]$Status
    )
    $PercentComplete = [Math]::Round(($Current / $Total) * 100)
    Write-Progress -Activity $Activity -Status $Status -CurrentOperation "$Current of $Total" -PercentComplete $PercentComplete
}

# 函數：備份原始設定
function Backup-OriginalSettings {
    Write-Log -Message "備份原始設定..." -Level "INFO"
    # 備份相關服務的啟動類型
    $OriginalSettings.Services = @{}
    $servicesToBackup = @(
        "DiagTrack", # 診斷追蹤服務
        "dmwappushsvc", # WAP Push Message Routing Service
        "DoSvc", # 傳送最佳化服務
        "PcaSvc", # 程式相容性助理服務
        "WerSvc" # Windows 錯誤報告服務
    )
    foreach ($serviceName in $servicesToBackup) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction Stop
            $OriginalSettings.Services[$serviceName] = $service.StartType
            Write-Log -Message "已備份服務 '$serviceName' 的啟動類型為 '$($service.StartType)'。" -Level "DEBUG"
        }
        catch [System.UnauthorizedAccessException] {
        Write-Log -Message "無權限執行操作：$($_.Exception.Message)" -Level "ERROR"
        return $false
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Log -Message "找不到指定的註冊表項目：$($_.Exception.Message)" -Level "WARN"
        return $false
    }
    catch {
            Write-Log -Message "無法備份服務 '$serviceName'：$($_.Exception.Message)" -Level "WARN"
        }
    }

    # 備份相關登錄檔鍵值
    $OriginalSettings.Registry = @{}
    $registryKeysToBackup = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\Settings",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"
    )
    foreach ($regPath in $registryKeysToBackup) {
        if (Test-Path $regPath) {
            $OriginalSettings.Registry[$regPath] = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue | Select-Object *
            Write-Log -Message "已備份登錄檔路徑 '$regPath'。" -Level "DEBUG"
        }
        else {
            Write-Log -Message "登錄檔路徑 '$regPath' 不存在，跳過備份。" -Level "DEBUG"
        }
    }
    Write-Log -Message "原始設定備份完成。" -Level "INFO"
}

# 函數：禁用遙測與診斷服務
function Disable-TelemetryServices {
    Write-Log -Message "正在禁用遙測與診斷服務..." -Level "INFO"
    $services = @(
        "DiagTrack", # 診斷追蹤服務
        "dmwappushsvc", # WAP Push Message Routing Service
        "DoSvc", # 傳送最佳化服務
        "PcaSvc", # 程式相容性助理服務
        "WerSvc" # Windows 錯誤報告服務
    )
    $totalServices = $services.Count
    for ($i = 0; $i -lt $totalServices; $i++) {
        $serviceName = $services[$i]
        Show-Progress -Current ($i + 1) -Total $totalServices -Activity "禁用服務" -Status "正在處理服務：$serviceName"
        try {
            if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
                if ((Get-Service -Name $serviceName).Status -eq 'Running') {
                    Write-Log -Message "正在停止服務 '$serviceName'..." -Level "DEBUG"
                    Stop-Service -Name $serviceName -Force -ErrorAction Stop -WhatIf:$WhatIf -Confirm:$Confirm
                }
                Write-Log -Message "正在禁用服務 '$serviceName'..." -Level "DEBUG"
                Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop -WhatIf:$WhatIf -Confirm:$Confirm
                Write-Log -Message "服務 '$serviceName' 已成功禁用。" -Level "INFO"
            }
            else {
                Write-Log -Message "服務 '$serviceName' 不存在，跳過。" -Level "WARN"
            }
        }
        catch [System.UnauthorizedAccessException] {
        Write-Log -Message "無權限執行操作：$($_.Exception.Message)" -Level "ERROR"
        return $false
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Log -Message "找不到指定的註冊表項目：$($_.Exception.Message)" -Level "WARN"
        return $false
    }
    catch {
            Write-Log -Message "禁用服務 '$serviceName' 失敗：$($_.Exception.Message)" -Level "ERROR"
        }
    }
    Write-Log -Message "遙測與診斷服務禁用完成。" -Level "INFO"
}

# 函數：修改登錄檔設定
function Modify-RegistrySettings {
    Write-Log -Message "正在修改登錄檔設定以禁用遙測..." -Level "INFO"

    # 禁用診斷資料收集
    $regPath1 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    $valueName1 = "AllowTelemetry"
    $valueData1 = 0
    if (-not (Test-Path $regPath1)) { New-Item -Path $regPath1 -Force | Out-Null }
    Set-ItemProperty -Path $regPath1 -Name $valueName1 -Value $valueData1 -Force -WhatIf:$WhatIf -Confirm:$Confirm
    Write-Log -Message "已設定登錄檔 '$regPath1\$valueName1' 為 '$valueData1'。" -Level "INFO"

    $regPath2 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    $valueName2 = "AllowTelemetry"
    $valueData2 = 0
    if (-not (Test-Path $regPath2)) { New-Item -Path $regPath2 -Force | Out-Null }
    Set-ItemProperty -Path $regPath2 -Name $valueName2 -Value $valueData2 -Force -WhatIf:$WhatIf -Confirm:$Confirm
    Write-Log -Message "已設定登錄檔 '$regPath2\$valueName2' 為 '$valueData2'。" -Level "INFO"

    # 禁用診斷追蹤服務的設定
    $regPath3 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\Settings"
    $valueName3 = "DisableMonitoring"
    $valueData3 = 1
    if (-not (Test-Path $regPath3)) { New-Item -Path $regPath3 -Force | Out-Null }
    Set-ItemProperty -Path $regPath3 -Name $valueName3 -Value $valueData3 -Force -WhatIf:$WhatIf -Confirm:$Confirm
    Write-Log -Message "已設定登錄檔 '$regPath3\$valueName3' 為 '$valueData3'。" -Level "INFO"

    # 禁用廣告 ID
    $regPath4 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"
    $valueName4 = "AdvertisingIdEnabled"
    $valueData4 = 0
    if (-not (Test-Path $regPath4)) { New-Item -Path $regPath4 -Force | Out-Null }
    Set-ItemProperty -Path $regPath4 -Name $valueName4 -Value $valueData4 -Force -WhatIf:$WhatIf -Confirm:$Confirm
    Write-Log -Message "已設定登錄檔 '$regPath4\$valueName4' 為 '$valueData4'。" -Level "INFO"

    Write-Log -Message "登錄檔設定修改完成。" -Level "INFO"
}

# 函數：生成檢測報告
function Generate-DetectionReport {
    Write-Log -Message "正在生成檢測報告..." -Level "INFO"
    $report = @{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Module = "F2_Telemetry_Disable"
        Status = "Completed"
        Details = @{}
    }

    # 檢查服務狀態
    $report.Details.Services = @{}
    $servicesToCheck = @(
        "DiagTrack",
        "dmwappushsvc",
        "DoSvc",
        "PcaSvc",
        "WerSvc"
    )
    foreach ($serviceName in $servicesToCheck) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                $report.Details.Services[$serviceName] = @{
                    Exists = $true
                    Status = $service.Status
                    StartType = $service.StartType
                }
            }
            else {
                $report.Details.Services[$serviceName] = @{ Exists = $false }
            }
        }
        catch [System.UnauthorizedAccessException] {
        Write-Log -Message "無權限執行操作：$($_.Exception.Message)" -Level "ERROR"
        return $false
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Log -Message "找不到指定的註冊表項目：$($_.Exception.Message)" -Level "WARN"
        return $false
    }
    catch {
            $report.Details.Services[$serviceName] = @{ Error = $_.Exception.Message }
        }
    }

    # 檢查登錄檔設定
    $report.Details.Registry = @{}
    $registrySettingsToCheck = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry"; Expected = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Expected = 0 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\Settings"; Name = "DisableMonitoring"; Expected = 1 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"; Name = "AdvertisingIdEnabled"; Expected = 0 }
    )
    foreach ($setting in $registrySettingsToCheck) {
        $regPath = $setting.Path
        $valueName = $setting.Name
        $expectedValue = $setting.Expected
        try {
            if (Test-Path $regPath) {
                $currentValue = (Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue).$valueName
                $report.Details.Registry["$regPath\$valueName"] = @{
                    Exists = $true
                    CurrentValue = $currentValue
                    ExpectedValue = $expectedValue
                    Match = ($currentValue -eq $expectedValue)
                }
            }
            else {
                $report.Details.Registry["$regPath\$valueName"] = @{ Exists = $false }
            }
        }
        catch [System.UnauthorizedAccessException] {
        Write-Log -Message "無權限執行操作：$($_.Exception.Message)" -Level "ERROR"
        return $false
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Log -Message "找不到指定的註冊表項目：$($_.Exception.Message)" -Level "WARN"
        return $false
    }
    catch {
            $report.Details.Registry["$regPath\$valueName"] = @{ Error = $_.Exception.Message }
        }
    }

    $reportJson = $report | ConvertTo-Json -Depth 100
    $reportJson | Out-File -FilePath $ReportFilePath -Encoding UTF8 -Force
    Write-Log -Message "檢測報告已生成：$ReportFilePath" -Level "INFO"
}

# 函數：回滾機制
function Rollback-Changes {
    Write-Log -Message "正在執行回滾操作..." -Level "INFO"

    # 回滾服務設定
    if ($OriginalSettings.Services) {
        foreach ($serviceName in $OriginalSettings.Services.Keys) {
            $originalStartType = $OriginalSettings.Services[$serviceName]
            try {
                if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
                    Write-Log -Message "正在將服務 '$serviceName' 的啟動類型恢復為 '$originalStartType'..." -Level "DEBUG"
                    Set-Service -Name $serviceName -StartupType $originalStartType -ErrorAction Stop -WhatIf:$WhatIf -Confirm:$Confirm
                    Write-Log -Message "服務 '$serviceName' 已成功恢復。" -Level "INFO"
                }
            }
            catch [System.UnauthorizedAccessException] {
        Write-Log -Message "無權限執行操作：$($_.Exception.Message)" -Level "ERROR"
        return $false
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Log -Message "找不到指定的註冊表項目：$($_.Exception.Message)" -Level "WARN"
        return $false
    }
    catch {
                Write-Log -Message "恢復服務 '$serviceName' 失敗：$($_.Exception.Message)" -Level "ERROR"
            }
        }
    }

    # 回滾登錄檔設定 (此處僅為示例，實際回滾可能需要更複雜的邏輯，例如恢復到備份的值或刪除新增的鍵值)
    # 由於登錄檔修改是設置特定值，回滾需要將其設置回原始值或默認值。
    # 這裡我們假設回滾是將值設置回其默認的啟用狀態或刪除。
    # 為了簡化，這裡僅將遙測相關的AllowTelemetry設置為1 (啟用)
    if ($OriginalSettings.Registry) {
        # 這裡需要更精確的回滾邏輯，例如根據備份的Get-ItemProperty結果來恢復。
        # 由於原始備份是Select-Object *，需要解析。
        # 為了演示，我們假設回滾是將AllowTelemetry設置為1。
        $regPath1 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
        $valueName1 = "AllowTelemetry"
        $valueData1 = 1 # 恢復為啟用
        if ($PSCmdlet.ShouldProcess("恢復登錄檔 '$regPath1\$valueName1'", "您確定要執行此操作嗎？")) {
            Set-ItemProperty -Path $regPath1 -Name $valueName1 -Value $valueData1 -Force -WhatIf:$WhatIf -Confirm:$Confirm
            Write-Log -Message "已將登錄檔 '$regPath1\$valueName1' 恢復為 '$valueData1'。" -Level "INFO"
        }

        $regPath2 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        $valueName2 = "AllowTelemetry"
        $valueData2 = 1 # 恢復為啟用
        if ($PSCmdlet.ShouldProcess("恢復登錄檔 '$regPath2\$valueName2'", "您確定要執行此操作嗎？")) {
            Set-ItemProperty -Path $regPath2 -Name $valueName2 -Value $valueData2 -Force -WhatIf:$WhatIf -Confirm:$Confirm
            Write-Log -Message "已將登錄檔 '$regPath2\$valueName2' 恢復為 '$valueData2'。" -Level "INFO"
        }

        $regPath3 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\Settings"
        $valueName3 = "DisableMonitoring"
        # 這裡需要判斷原始值，如果原始沒有這個鍵值，則刪除，否則恢復原始值。
        # 為了簡化，這裡假設是恢復到默認值0 (啟用監控)
        $valueData3 = 0
        if ($PSCmdlet.ShouldProcess("恢復登錄檔 '$regPath3\$valueName3'", "您確定要執行此操作嗎？")) {
            Set-ItemProperty -Path $regPath3 -Name $valueName3 -Value $valueData3 -Force -WhatIf:$WhatIf -Confirm:$Confirm
            Write-Log -Message "已將登錄檔 '$regPath3\$valueName3' 恢復為 '$valueData3'。" -Level "INFO"
        }

        $regPath4 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"
        $valueName4 = "AdvertisingIdEnabled"
        $valueData4 = 1 # 恢復為啟用
        if ($PSCmdlet.ShouldProcess("恢復登錄檔 '$regPath4\$valueName4'", "您確定要執行此操作嗎？")) {
            Set-ItemProperty -Path $regPath4 -Name $valueName4 -Value $valueData4 -Force -WhatIf:$WhatIf -Confirm:$Confirm
            Write-Log -Message "已將登錄檔 '$regPath4\$valueName4' 恢復為 '$valueData4'。" -Level "INFO"
        }
    }

    Write-Log -Message "回滾操作完成。" -Level "INFO"
}

# 主要執行邏輯
function Main {
    Set-LogConfiguration # 初始化日誌配置
    Write-Log -Message "腳本開始執行：F2_Telemetry_Disable - Windows 遙測與診斷禁用模塊" -Level "INFO"

    # 備份原始設定
    Backup-OriginalSettings

    # 錯誤處理
    try {
        # 執行禁用操作
        if ($PSCmdlet.ShouldProcess("禁用 Windows 遙測與診斷功能", "您確定要執行此操作嗎？")) {
            Disable-TelemetryServices
            Modify-RegistrySettings
            Generate-DetectionReport
        }
    }
    catch [System.UnauthorizedAccessException] {
        Write-Log -Message "無權限執行操作：$($_.Exception.Message)" -Level "ERROR"
        return $false
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Log -Message "找不到指定的註冊表項目：$($_.Exception.Message)" -Level "WARN"
        return $false
    }
    catch {
        Write-Log -Message "執行過程中發生錯誤：$($_.Exception.Message)" -Level "ERROR"
        Write-Log -Message "正在嘗試回滾變更..." -Level "WARN"
        Rollback-Changes
    }
    finally {
        Write-Log -Message "腳本執行完成。" -Level "INFO"
    }
}

# 執行主函數
Main
