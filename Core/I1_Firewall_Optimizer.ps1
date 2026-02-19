<#
.SYNOPSIS
    I1_Firewall_Optimizer - 交互式防火牆優化工具

.DESCRIPTION
    此腳本提供一個交互式界面，幫助用戶優化 Windows 防火牆規則。它會根據功能分類防火牆規則，
    詢問用戶是否使用特定功能，並自動禁用不需要的規則和相關服務，最後生成一份優化報告。

.PARAMETER WhatIf
    描述當運行命令時會發生什麼，但實際上不執行命令。

.PARAMETER Confirm
    提示您在運行命令之前進行確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
    編碼：UTF-8 with BOM
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$WhatIf,
    [switch]$Confirm
)

#region 函數定義

# 設置日誌函數
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Level = 'INFO' # INFO, WARN, ERROR, DEBUG
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"
    Write-Host $LogEntry
    # 實際應用中可以將日誌寫入文件，例如：
    # Add-Content -Path "$PSScriptRoot\I1_Firewall_Optimizer.log" -Value $LogEntry -Encoding UTF8
}

# 顯示進度函數
function Update-Progress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Activity,
        [Parameter(Mandatory=$true)]
        [string]$Status,
        [Parameter(Mandatory=$true)]
        [int]$PercentComplete
    )
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

#endregion

#region 主邏輯

Write-Log -Message "I1_Firewall_Optimizer 腳本啟動..."
Update-Progress -Activity "初始化" -Status "正在準備環境..." -PercentComplete 10

# 檢查是否以管理員權限運行
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log -Message "此腳本需要管理員權限才能運行。請以管理員身份重新啟動。" -Level "ERROR"
    exit 1
}

# 獲取所有防火牆規則
Write-Log -Message "正在獲取防火牆規則..." -Level "INFO"
Update-Progress -Activity "獲取規則" -Status "正在從系統讀取防火牆規則..." -PercentComplete 30

try {
    $allFirewallRules = Get-NetFirewallRule -ErrorAction Stop | Where-Object {$_.Enabled -eq $true -and $_.Direction -eq 'Inbound'}
    Write-Log -Message "成功獲取 $($allFirewallRules.Count) 條入站防火牆規則。" -Level "INFO"
} catch {
    Write-Log -Message "獲取防火牆規則時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

# 根據 DisplayGroup 分類規則
Write-Log -Message "正在分類防火牆規則..." -Level "INFO"
Update-Progress -Activity "分類規則" -Status "正在按功能分類規則..." -PercentComplete 50
$categorizedRules = $allFirewallRules | Group-Object -Property DisplayGroup

$rulesToDisable = @()
$servicesToStopAndDisable = @()

foreach ($group in $categorizedRules) {
    $functionName = $group.Name
    Write-Host "`n" # 添加空行以提高可讀性
    $prompt = "您是否使用功能 '$functionName'？ (Y/N) "
    $response = Read-Host $prompt

    if ($response -ne 'Y' -and $response -ne 'y') {
        Write-Log -Message "用戶選擇禁用功能 '$functionName'。" -Level "INFO"
        foreach ($rule in $group.Group) {
            # 檢查規則是否已啟用且為入站規則
            if ($rule.Enabled -eq $true -and $rule.Direction -eq 'Inbound') {
                $rulesToDisable += $rule

                # 嘗試從規則中提取相關服務 (這部分可能需要更複雜的邏輯來準確判斷)
                # 這裡只是一個簡化的示例，實際應用中可能需要查詢服務與防火牆規則的映射關係
                if ($rule.DisplayName -match "服務名稱: (\w+)") {
                    $serviceName = $Matches[1]
                    try {
                        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                        if ($service -and $service.Status -eq 'Running') {
                            $servicesToStopAndDisable += $service
                        }
                    } catch {
                        Write-Log -Message "無法獲取服務 '$serviceName' 的信息: $($_.Exception.Message)" -Level "WARN"
                    }
                }
            }
        }
    } else {
        Write-Log -Message "用戶選擇保留功能 '$functionName'。" -Level "INFO"
    }
    Update-Progress -Activity "交互式詢問" -Status "正在處理功能 '$functionName'..." -PercentComplete ($PercentComplete + 10)
}

Write-Log -Message "正在禁用不需要的防火牆規則和服務..." -Level "INFO"
Update-Progress -Activity "執行優化" -Status "正在禁用選定的規則和服務..." -PercentComplete 80

if ($PSCmdlet.ShouldProcess("禁用選定的防火牆規則和服務", "您確定要禁用這些規則和服務嗎？")) {
    foreach ($rule in $rulesToDisable) {
        try {
            Write-Log -Message "正在禁用防火牆規則: $($rule.DisplayName) (Name: $($rule.Name))" -Level "INFO"
            Set-NetFirewallRule -Name $rule.Name -Enabled False -ErrorAction Stop
        } catch {
            Write-Log -Message "禁用防火牆規則 '$($rule.DisplayName)' 時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
        }
    }

    foreach ($service in $servicesToStopAndDisable) {
        try {
            Write-Log -Message "正在停止服務: $($service.DisplayName) (Name: $($service.Name))" -Level "INFO"
            Stop-Service -Name $service.Name -Force -ErrorAction Stop
            Write-Log -Message "正在禁用服務: $($service.DisplayName) (Name: $($service.Name))" -Level "INFO"
            Set-Service -Name $service.Name -StartupType Disabled -ErrorAction Stop
        } catch {
            Write-Log -Message "停止或禁用服務 '$($service.DisplayName)' 時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

Write-Log -Message "正在生成優化報告..." -Level "INFO"
Update-Progress -Activity "生成報告" -Status "正在創建優化報告..." -PercentComplete 90

$reportData = @{
    Timestamp = (Get-Date).ToString()
    DisabledRules = $rulesToDisable | Select-Object DisplayName, Name, Description, DisplayGroup, ServiceName, Enabled, Direction, Action, Profile, LocalAddress, RemoteAddress, LocalPort, RemotePort, Protocol
    StoppedAndDisabledServices = $servicesToStopAndDisable | Select-Object DisplayName, Name, Status, StartType
    # 可以添加更多詳細信息，例如優化前後的規則數量、建議的回滾步驟等
}

$reportPath = Join-Path $PSScriptRoot "I1_Firewall_Optimizer_Report.json"

try {
    $reportData | ConvertTo-Json -Depth 100 | Set-Content -Path $reportPath -Encoding UTF8 -ErrorAction Stop
    Write-Log -Message "優化報告已生成: $reportPath" -Level "INFO"
} catch {
    Write-Log -Message "生成優化報告時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
}

Update-Progress -Activity "完成" -Status "防火牆優化工具運行完成。" -PercentComplete 100
Write-Log -Message "I1_Firewall_Optimizer 腳本運行完成。" -Level "INFO"

#endregion
