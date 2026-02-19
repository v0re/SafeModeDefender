﻿# encoding: utf-8
<#
.SYNOPSIS
    C4_WMI_Events - WMI 事件訂閱檢測模塊

.DESCRIPTION
    此 PowerShell 腳本用於檢測系統中惡意的 WMI 事件訂閱，這些訂閱可能被攻擊者用於持久化或權限提升。
    腳本會檢查 WMI 事件篩選器 (EventFilter)、事件消費者 (EventConsumer) 和篩選器到消費者綁定 (FilterToConsumerBinding) 物件。
    同時，它也支援 -WhatIf 和 -Confirm 參數，提供多級別日誌記錄和進度顯示，並生成 JSON 格式的檢測報告。

.PARAMETER WhatIf
    如果指定此參數，腳本將描述在執行時會發生什麼，但不會實際執行任何操作。

.PARAMETER Confirm
    如果指定此參數，腳本將在執行任何操作之前提示確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    要求：Windows 10 或更高版本，具有管理員權限。
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param()

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Level = "INFO" # INFO, WARN, ERROR, DEBUG
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"
    Write-Host $LogEntry
    # 實際應用中可以將日誌寫入檔案
}

function New-DetectionReportEntry {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Type,
        [Parameter(Mandatory=$true)]
        [string]$Description,
        [string]$Details = ""
    )
    [PSCustomObject]@{ 
        Type = $Type
        Description = $Description
        Details = $Details
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
}

Write-Log -Message "C4_WMI_Events - WMI 事件訂閱檢測模塊啟動..."

$detectionReport = @()

# 檢測 WMI 事件篩選器 (EventFilter)
Write-Log -Message "正在檢測 WMI 事件篩選器 (EventFilter)..."
$filters = Get-WmiObject -Namespace "root\subscription" -Class "__EventFilter" -ErrorAction SilentlyContinue
if ($filters) {
    foreach ($filter in $filters) {
        Write-Log -Message "發現 WMI 事件篩選器: $($filter.Name) (查詢: $($filter.Query))" -Level "INFO"
        $detectionReport += New-DetectionReportEntry -Type "WMI EventFilter" -Description "發現潛在惡意 WMI 事件篩選器" -Details "名稱: $($filter.Name), 查詢: $($filter.Query), 提供者: $($filter.EventNamespace)"
    }
} else {
    Write-Log -Message "未發現任何 WMI 事件篩選器。" -Level "INFO"
}

# 檢測 WMI 事件消費者 (EventConsumer)
Write-Log -Message "正在檢測 WMI 事件消費者 (EventConsumer)..."
$consumers = Get-WmiObject -Namespace "root\subscription" -Class "__EventConsumer" -ErrorAction SilentlyContinue
if ($consumers) {
    foreach ($consumer in $consumers) {
        Write-Log -Message "發現 WMI 事件消費者: $($consumer.Name) (類型: $($consumer.__CLASS))" -Level "INFO"
        $detectionReport += New-DetectionReportEntry -Type "WMI EventConsumer" -Description "發現潛在惡意 WMI 事件消費者" -Details "名稱: $($consumer.Name), 類型: $($consumer.__CLASS), 執行命令: $($consumer.CommandLineTemplate)"
    }
} else {
    Write-Log -Message "未發現任何 WMI 事件消費者。" -Level "INFO"
}

# 檢測 WMI 篩選器到消費者綁定 (FilterToConsumerBinding)
Write-Log -Message "正在檢測 WMI 篩選器到消費者綁定 (FilterToConsumerBinding)..."
$bindings = Get-WmiObject -Namespace "root\subscription" -Class "__FilterToConsumerBinding" -ErrorAction SilentlyContinue
if ($bindings) {
    foreach ($binding in $bindings) {
        $filterName = ($binding.Filter -split ":")[-1].Replace("`"", "")
        $consumerName = ($binding.Consumer -split ":")[-1].Replace("`"", "")
        Write-Log -Message "發現 WMI 綁定: 篩選器: $($filterName), 消費者: $($consumerName)" -Level "INFO"
        $detectionReport += New-DetectionReportEntry -Type "WMI Binding" -Description "發現潛在惡意 WMI 綁定" -Details "篩選器: $($filterName), 消費者: $($consumerName)"
    }
} else {
    Write-Log -Message "未發現任何 WMI 篩選器到消費者綁定。" -Level "INFO"
}

# 生成 JSON 報告
$reportPath = Join-Path $PSScriptRoot "C4_WMI_Events_Detection_Report.json"
$detectionReport | ConvertTo-Json -Depth 100 | Set-Content -Path $reportPath -Encoding UTF8
Write-Log -Message "檢測報告已生成至 $reportPath" -Level "INFO"

Write-Log -Message "C4_WMI_Events - WMI 事件訂閱檢測模塊完成。"
