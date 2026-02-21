# encoding: utf-8
<#
.SYNOPSIS
    E3_GPU_Protection - 顯示卡渲染溢出防護模塊
    此腳本旨在強化 Windows 系統的顯示卡渲染溢出防護，主要透過啟用 IOMMU-based GPU isolation 機制。

.DESCRIPTION
    本 PowerShell 腳本用於檢測和啟用 Windows 10 及更高版本中的 IOMMU-based GPU isolation 功能。
    此功能透過硬體虛擬化技術，限制 GPU 對系統記憶體的直接存取，從而防止顯示卡驅動程式中的緩衝區溢出漏洞被惡意利用。
    腳本支援 -WhatIf 和 -Confirm 參數，提供多級別日誌記錄，進度顯示，並能生成 JSON 格式的檢測報告。

.PARAMETER EnableProtection
    啟用顯示卡渲染溢出防護。此操作會修改註冊表並需要重新啟動系統。

.PARAMETER CheckStatus
    檢查當前顯示卡渲染溢出防護的狀態。

.PARAMETER DisableProtection
    禁用顯示卡渲染溢出防護。此操作會修改註冊表並需要重新啟動系統，用於回滾。

.PARAMETER WhatIf
    顯示如果執行命令會發生什麼，但不實際執行命令。

.PARAMETER Confirm
    在執行命令前提示您進行確認。

.NOTES
    作者：Manus AI
    版本：1.1
    日期：2026-02-18
    要求：Windows 10 版本 1803 (WDDM 2.4) 或更高版本，且系統支援 IOMMU 硬體虛擬化。

.EXAMPLE
    .\E3_GPU_Protection.ps1 -EnableProtection
    啟用 GPU 渲染溢出防護。

.EXAMPLE
    .\E3_GPU_Protection.ps1 -CheckStatus
    檢查當前 GPU 渲染溢出防護狀態。

.EXAMPLE
    .\E3_GPU_Protection.ps1 -EnableProtection -WhatIf
    預覽啟用 GPU 渲染溢出防護將執行的操作。

.EXAMPLE
    .\E3_GPU_Protection.ps1 -EnableProtection -Confirm
    在啟用 GPU 渲染溢出防護前提示確認。
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact=\'High\')]
param(
    [switch]$EnableProtection,
    [switch]$CheckStatus,
    [switch]$DisableProtection
)

#region 函數定義

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = \'INFO\' # INFO, WARN, ERROR, DEBUG
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"
    Write-Host $LogEntry
    # 實際應用中可將日誌寫入檔案，例如：Add-Content -Path "E3_GPU_Protection.log" -Value $LogEntry
}

function Get-IOMMUFlags {
    Write-Log "正在讀取 IOMMUFlags 註冊表值..." \'DEBUG\'
    try {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        $regValue = Get-ItemProperty -Path $regPath -Name "IOMMUFlags" -ErrorAction SilentlyContinue
        if ($regValue) {
            return $regValue.IOMMUFlags
        } else {
            Write-Log "IOMMUFlags 註冊表值不存在，視為 0。" \'INFO\'
            return 0
        }
    }
    catch {
        Write-Log "讀取 IOMMUFlags 註冊表值失敗：$($_.Exception.Message)" \'ERROR\'
        return $null
    }
}

function Set-IOMMUFlags {
    param(
        [int]$Value
    )
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    $regName = "IOMMUFlags"
    
    if ($PSCmdlet.ShouldProcess("設定註冊表值 \'$regName\' 為 \'$Value\'", "您確定要設定 IOMMUFlags 註冊表值嗎？", \'高\')) {
        try {
            Set-ItemProperty -Path $regPath -Name $regName -Value $Value -Force -ErrorAction Stop
            Write-Log "成功設定 IOMMUFlags 註冊表值為 $Value。" \'INFO\'
            return $true
        }
        catch {
            Write-Log "設定 IOMMUFlags 註冊表值失敗：$($_.Exception.Message)" \'ERROR\'
            return $false
        }
    }
    return $false
}

function Test-IOMMUSupport {
    Write-Log "正在檢測系統是否支援 IOMMU..." \'INFO\'
    Write-Progress -Activity "檢測 IOMMU 支援" -Status "檢查作業系統版本" -PercentComplete 20

    # 1. 檢查 Windows 版本 (WDDM 2.4 要求 Windows 10 1803 或更高)
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10 -or ($osVersion.Major -eq 10 -and $osVersion.Build -lt 17134)) {
        Write-Log "系統版本低於 Windows 10 版本 1803 (Build 17134)，不支援 IOMMU-based GPU isolation。" \'WARN\'
        return $false
    }
    Write-Log "作業系統版本符合要求 (Windows 10 1803 或更高)。" \'INFO\'
    Write-Progress -Activity "檢測 IOMMU 支援" -Status "檢查 BIOS/UEFI 設定" -PercentComplete 40

    # 2. 檢查 BIOS/UEFI 中的 IOMMU 虛擬化設定
    # 由於無法直接從 PowerShell 檢測 BIOS 設定，這裡提供一個提示。
    # 實際部署時，可能需要手動檢查或依賴系統管理工具。
    Write-Log "請確保您的 BIOS/UEFI 中已啟用 Intel VT-d 或 AMD-Vi (IOMMU)。" \'WARN\'
    Write-Progress -Activity "檢測 IOMMU 支援" -Status "檢查裝置管理員" -PercentComplete 60

    # 3. 檢查裝置管理員中的 IOMMU 相關裝置狀態 (例如 PCI-to-PCI Bridge)
    # 這部分也難以直接自動化，但可以檢查系統資訊。
    try {
        $systemInfo = Get-ComputerInfo -Property HyperVisorPresent, VmMonitorPresent
        if ($systemInfo.HyperVisorPresent -and $systemInfo.VmMonitorPresent) {
            Write-Log "Hyper-V 和 VM 監視器已啟用，可能表示 IOMMU 已在運作。" \'INFO\'
        } else {
            Write-Log "Hyper-V 或 VM 監視器未啟用，請手動檢查 IOMMU 狀態。" \'WARN\'
        }
    }
    catch {
        Write-Log "無法獲取 Hyper-V 狀態：$($_.Exception.Message)" \'WARN\'
    }
    Write-Progress -Activity "檢測 IOMMU 支援" -Status "完成" -PercentComplete 100 -Completed

    Write-Log "系統可能支援 IOMMU，但請手動確認 BIOS/UEFI 設定。" \'INFO\'
    return $true
}

#endregion

#region 主邏輯

$report = @{
    ModuleId = "E3_GPU_Protection"
    ModuleName = "顯示卡渲染溢出防護模塊"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Status = "未知"
    Details = @{}
}

# 檢查 IOMMU 支援，如果不支持則直接退出
if (-not (Test-IOMMUSupport)) {
    $report.Status = "不適用"
    $report.Details.ErrorMessage = "系統不支援 IOMMU-based GPU isolation 或版本過低。"
    Write-Log "此模塊不適用於當前系統。" \'ERROR\'
    Write-Output ($report | ConvertTo-Json -Depth 100 -Compress)
    exit 1
}

if ($CheckStatus) {
    Write-Log "正在檢查顯示卡渲染溢出防護狀態..." \'INFO\'
    Write-Progress -Activity "檢查防護狀態" -Status "讀取註冊表" -PercentComplete 50
    $currentFlags = Get-IOMMUFlags
    if ($currentFlags -eq $null) {
        $report.Status = "錯誤"
        $report.Details.ErrorMessage = "無法獲取 IOMMUFlags 註冊表值。"
        Write-Log "無法獲取 IOMMUFlags 註冊表值。" \'ERROR\'
    }
    elseif ($currentFlags -band 0x07 -eq 0x07) {
        $report.Status = "已啟用"
        $report.Details.IOMMUFlags = $currentFlags
        Write-Log "IOMMU-based GPU isolation 已啟用 (IOMMUFlags: $currentFlags)。" \'INFO\'
    }
    else {
        $report.Status = "未啟用"
        $report.Details.IOMMUFlags = $currentFlags
        Write-Log "IOMMU-based GPU isolation 未完全啟用 (IOMMUFlags: $currentFlags)。" \'WARN\'
    }
    Write-Progress -Activity "檢查防護狀態" -Status "完成" -PercentComplete 100 -Completed
}
elseif ($EnableProtection) {
    Write-Log "正在嘗試啟用顯示卡渲染溢出防護..." \'INFO\'
    Write-Progress -Activity "啟用防護" -Status "設定註冊表" -PercentComplete 50
    $targetFlags = 0x07 # 0x01 Enabled | 0x02 EnableMappings | 0x04 EnableAttach
    if (Set-IOMMUFlags -Value $targetFlags) {
        $report.Status = "已啟用"
        $report.Details.IOMMUFlags = $targetFlags
        Write-Log "顯示卡渲染溢出防護已成功啟用。請重啟系統以使更改生效。" \'INFO\'
    }
    else {
        $report.Status = "啟用失敗"
        $report.Details.ErrorMessage = "設定 IOMMUFlags 註冊表值失敗。"
        Write-Log "設定 IOMMUFlags 註冊表值失敗。" \'ERROR\'
    }
    Write-Progress -Activity "啟用防護" -Status "完成" -PercentComplete 100 -Completed
}
elseif ($DisableProtection) {
    Write-Log "正在嘗試禁用顯示卡渲染溢出防護..." \'INFO\'
    Write-Progress -Activity "禁用防護" -Status "設定註冊表" -PercentComplete 50
    $targetFlags = 0x00 # 禁用所有 IOMMUFlags
    if (Set-IOMMUFlags -Value $targetFlags) {
        $report.Status = "已禁用"
        $report.Details.IOMMUFlags = $targetFlags
        Write-Log "顯示卡渲染溢出防護已成功禁用。請重啟系統以使更改生效。" \'INFO\'
    }
    else {
        $report.Status = "禁用失敗"
        $report.Details.ErrorMessage = "設定 IOMMUFlags 註冊表值失敗。"
        Write-Log "設定 IOMMUFlags 註冊表值失敗。" \'ERROR\'
    }
    Write-Progress -Activity "禁用防護" -Status "完成" -PercentComplete 100 -Completed
}
else {
    $report.Status = "無操作"
    $report.Details.ErrorMessage = "請指定操作參數 (-EnableProtection, -CheckStatus 或 -DisableProtection)。"
    Write-Log "請指定操作參數 (-EnableProtection, -CheckStatus 或 -DisableProtection)。" \'WARN\'
}

Write-Output ($report | ConvertTo-Json -Depth 100 -Compress)

#endregion
