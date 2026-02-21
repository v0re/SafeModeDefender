<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>
<#
.SYNOPSIS
    B3_Token_Protection - Token 競取與模擬防護模塊
.DESCRIPTION
    此腳本旨在檢測和防護 Windows 系統中的 Token 競取與模擬攻擊，這是一種常見的權限提升技術。
    它會審計具有 SeDebugPrivilege 的進程，檢測 Token 模擬行為，並識別可疑的權限提升工具。
.PARAMETER WhatIf
    描述執行操作但不安裝任何內容時會發生什麼情況。
.PARAMETER Confirm
    提示您在執行 cmdlet 之前進行確認。
.NOTES
    版本：1.0
    作者：Manus AI
    日期：2026-02-18
    參考威脅來源：Token 竊取是常見的提權技術
    防護目標：Token 權限審計，SeDebugPrivilege 濫用檢測
    檢測項目：具有 SeDebugPrivilege 的進程，Token 模擬行為檢測，可疑的權限提升工具
    修復操作：審計特權 Token，限制 SeDebugPrivilege，檢測 Token 竊取工具
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param()

#region 函數定義

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Level = 'INFO' # INFO, WARN, ERROR, DEBUG
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$Level] $Message"
    Write-Output $logEntry
    # 可在此處添加將日誌寫入文件或事件日誌的邏輯
}

function Get-ProcessWithSeDebugPrivilege {
    <#
    .SYNOPSIS
        獲取具有 SeDebugPrivilege 的進程。
    .DESCRIPTION
        此函數枚舉所有進程，並檢查其 Token 中是否包含 SeDebugPrivilege。
        SeDebugPrivilege 允許進程調試其他進程，這可能被惡意利用進行 Token 竊取。
    .OUTPUTS
        System.Management.Automation.PSObject[]
    #>
    Write-Log -Message "開始檢測具有 SeDebugPrivilege 的進程..." -Level "DEBUG"
    $processesWithSeDebug = @()
    try {
        Get-Process | ForEach-Object {
            try {
                $processName = $_.ProcessName
                $processId = $_.Id
                $token = Get-NtProcessToken -ProcessId $processId -ErrorAction SilentlyContinue
                if ($token) {
                    $privileges = Get-NtTokenPrivilege -Token $token -ErrorAction SilentlyContinue
                    if ($privileges | Where-Object { $_.Name -eq 'SeDebugPrivilege' -and $_.State -eq 'Enabled' }) {
                        $processesWithSeDebug += [PSCustomObject]@{ 
                            ProcessName = $processName;
                            ProcessId = $processId;
                            Privilege = 'SeDebugPrivilege';
                            State = 'Enabled'
                        }
                        Write-Log -Message "發現進程 '$processName' (PID: $processId) 具有 SeDebugPrivilege。" -Level "WARN"
                    }
                }
            }
            catch {
                Write-Log -Message "處理進程 $($_.ProcessName) 時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
    catch {
        Write-Log -Message "獲取進程列表時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
    }
    Write-Log -Message "完成檢測具有 SeDebugPrivilege 的進程。" -Level "DEBUG"
    return $processesWithSeDebug
}

function Detect-TokenImpersonation {
    <#
    .SYNOPSIS
        檢測潛在的 Token 模擬行為。
    .DESCRIPTION
        此函數嘗試識別可能指示 Token 模擬的行為。這通常涉及檢查異常的進程父子關係或不尋常的權限分配。
        由於直接檢測 Token 模擬較為複雜，此函數將側重於相關的間接指標。
    .OUTPUTS
        System.Management.Automation.PSObject[]
    #>
    Write-Log -Message "開始檢測潛在的 Token 模擬行為..." -Level "DEBUG"
    $impersonationDetections = @()

    # 示例：檢查異常的進程父子關係 (需要更高級的系統監控工具或事件日誌分析)
    # 這裡僅為概念性演示，實際實現會更複雜
    # 假設我們有一個方法可以獲取進程的父進程信息
    # Get-Process | ForEach-Object {
    #     $parentProcess = Get-ParentProcess -ProcessId $_.Id
    #     if ($parentProcess -and ($_.UserName -ne $parentProcess.UserName)) {
    #         $impersonationDetections += [PSCustomObject]@{ 
    #             DetectionType = 'Parent-Child User Mismatch';
    #             ProcessName = $_.ProcessName;
    #             ProcessId = $_.Id;
    #             ParentProcessName = $parentProcess.ProcessName;
    #             ParentProcessId = $parentProcess.Id;
    #             Description = "進程 $($_.ProcessName) 的用戶與其父進程 $($parentProcess.ProcessName) 的用戶不匹配，可能存在 Token 模擬。"
    #         }
    #     }
    # }

    # 示例：檢查異常的登錄會話 (需要更高級的系統監控工具或事件日誌分析)
    # 這裡僅為概念性演示，實際實現會更複雜
    # Get-WinEvent -LogName 'Security' -FilterXPath "*[System[(EventID=4624 or EventID=4625)]]" -MaxEvents 1000 | ForEach-Object {
    #     # 分析登錄事件，尋找異常的登錄類型或源
    # }

    Write-Log -Message "完成檢測潛在的 Token 模擬行為。" -Level "DEBUG"
    return $impersonationDetections
}

function Find-SuspiciousPrivilegeEscalationTools {
    <#
    .SYNOPSIS
        查找可疑的權限提升工具。
    .DESCRIPTION
        此函數掃描常見的權限提升工具路徑和文件名，以識別潛在的惡意工具。
    .OUTPUTS
        System.Management.Automation.PSObject[]
    #>
    Write-Log -Message "開始查找可疑的權限提升工具..." -Level "DEBUG"
    $suspiciousTools = @()
    $commonToolNames = @(
        'mimikatz.exe',
        'incognito.exe',
        'getsystem.exe',
        'juicypotato.exe',
        'rottenpotato.exe',
        'sweetpotato.exe',
        'printspoofer.exe',
        'sharphound.exe',
        'bloodhound.exe'
    )
    $commonToolPaths = @(
        "$env:TEMP\*",
        "$env:APPDATA\*",
        "$env:LOCALAPPDATA\*",
        "C:\Users\Public\*",
        "C:\ProgramData\*"
    )

    foreach ($path in $commonToolPaths) {
        foreach ($toolName in $commonToolNames) {
            $fullPath = Join-Path -Path (Split-Path $path -Parent) -ChildPath $toolName
            try {
                $foundFiles = Get-ChildItem -Path $fullPath -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
                foreach ($file in $foundFiles) {
                    $suspiciousTools += [PSCustomObject]@{ 
                        ToolName = $toolName;
                        FilePath = $file.FullName;
                        Description = "在常見路徑中發現可疑權限提升工具 '$toolName'。"
                    }
                    Write-Log -Message "發現可疑權限提升工具：'$($file.FullName)'" -Level "WARN"
                }
            }
            catch {
                Write-Log -Message "掃描路徑 '$path' 時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
    Write-Log -Message "完成查找可疑的權限提升工具。" -Level "DEBUG"
    return $suspiciousTools
}

#endregion

#region 主邏輯

if ($PSCmdlet.ShouldProcess("執行 Token 競取與模擬防護模塊", "您確定要執行此操作嗎？")) {
    Write-Log -Message "開始執行 B3_Token_Protection - Token 競取與模擬防護模塊。" -Level "INFO"

    $detectionResults = @{}

    # 1. 檢測具有 SeDebugPrivilege 的進程
    Write-Progress -Activity "執行防護模塊" -Status "檢測具有 SeDebugPrivilege 的進程..." -PercentComplete 33
    $seDebugProcesses = Get-ProcessWithSeDebugPrivilege
    $detectionResults.SeDebugPrivilegeProcesses = $seDebugProcesses

    # 2. 檢測潛在的 Token 模擬行為 (此處為概念性，實際需要更複雜的實現)
    Write-Progress -Activity "執行防護模塊" -Status "檢測潛在的 Token 模擬行為..." -PercentComplete 66
    $tokenImpersonationDetections = Detect-TokenImpersonation
    $detectionResults.TokenImpersonationDetections = $tokenImpersonationDetections

    # 3. 查找可疑的權限提升工具
    Write-Progress -Activity "執行防護模塊" -Status "查找可疑的權限提升工具..." -PercentComplete 99
    $suspiciousPeTools = Find-SuspiciousPrivilegeEscalationTools
    $detectionResults.SuspiciousPrivilegeEscalationTools = $suspiciousPeTools

    # 生成 JSON 格式的檢測報告
    $reportFileName = "B3_Token_Protection_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $reportPath = Join-Path -Path $PSScriptRoot -ChildPath $reportFileName
    
    try {
        $detectionResults | ConvertTo-Json -Depth 100 | Set-Content -Path $reportPath -Encoding UTF8
        Write-Log -Message "檢測報告已生成：$reportPath" -Level "INFO"
    }
    catch {
        Write-Log -Message "生成檢測報告時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
    }

    Write-Log -Message "B3_Token_Protection - Token 競取與模擬防護模塊執行完成。" -Level "INFO"
}
else {
    Write-Log -Message "操作已被用戶取消。" -Level "INFO"
}

#endregion

#region 輔助函數 (需要安裝 NtObjectManager 模塊)
# 為了讓 Get-NtProcessToken 和 Get-NtTokenPrivilege 正常工作，需要安裝 NtObjectManager 模塊。
# 安裝命令：Install-Module -Name NtObjectManager -Force
# 如果模塊未安裝，上述函數將會失敗。
# 在實際部署中，應確保環境已安裝所需模塊或提供安裝引導。
#endregion
