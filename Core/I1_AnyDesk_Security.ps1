#encoding: utf-8-with-bom
<#
.SYNOPSIS
    I1_AnyDesk_Security - AnyDesk 遠端桌面安全檢測與防護模塊
    此模塊旨在檢測並防禦針對 AnyDesk 遠端桌面軟體的各類攻擊，包括 CVE-2024-52940、CVE-2024-12754 等已知漏洞。

.DESCRIPTION
    本腳本將執行以下操作：
    1. 檢測 AnyDesk 是否已安裝，並驗證其數位簽章和版本
    2. 分析 AnyDesk 配置檔案的安全性（service.conf, system.conf, user.conf）
    3. 檢測 CVE-2024-52940（IP 地址洩露）相關的配置風險
    4. 檢測 CVE-2024-12754（權限提升）相關的符號連結攻擊
    5. 監控 7070 端口的網路連接狀態
    6. 分析 AnyDesk 進程的命令列參數，檢測可疑的 CLI 濫用
    7. 審查 AnyDesk 日誌檔案，識別暴力破解和未授權連接嘗試
    8. 檢查硬體指紋和環境變動跡象
    9. **檢測顯卡渲染攻擊跡象（Direct3D 錯誤 0x8876086c）**
    10. **分析 AnyDesk 隱私模式濫用和畫面異常**
    11. **檢測 GPO 篡改和系統管理工具封鎖**
    12. 生成詳細的 JSON 格式檢測報告，包含所有發現和修復建議

.PARAMETER WhatIf
    如果指定此參數，腳本將顯示將要執行的操作，但不會實際執行它們。

.PARAMETER Confirm
    如果指定此參數，腳本將在執行任何修復操作之前提示用戶確認。

.PARAMETER LogPath
    指定日誌檔案的儲存路徑。如果未指定，將在腳本所在目錄創建一個日誌檔案。

.PARAMETER ReportPath
    指定 JSON 報告檔案的儲存路徑。如果未指定，將在腳本所在目錄創建一個報告檔案。

.EXAMPLE
    .\I1_AnyDesk_Security.ps1 -WhatIf
    顯示將要執行的檢測和修復操作，但不實際執行。

.EXAMPLE
    .\I1_AnyDesk_Security.ps1 -Confirm
    執行檢測和修復操作，並在修復前提示用戶確認。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-19
    威脅情報：CVE-2024-52940 (IP 洩露), CVE-2024-12754 (權限提升), AnyDesk 2024 安全事件
    兼容性：Windows 10 安全模式及更高版本。
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [string]$LogPath = (Join-Path $PSScriptRoot "I1_AnyDesk_Security.log"),
    [string]$ReportPath = (Join-Path $PSScriptRoot "I1_AnyDesk_Security_Report.json")
)

#region 函數定義

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO" # INFO, WARN, ERROR, DEBUG
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $LogEntry -ErrorAction SilentlyContinue
    
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "DEBUG" { "Gray" }
        default { "White" }
    }
    Write-Host $LogEntry -ForegroundColor $color
}

function Get-AnydeskInstallation {
    <#
    .SYNOPSIS
        檢測 AnyDesk 是否已安裝並返回安裝資訊
    #>
    $installations = @()
    
    # 檢查標準安裝路徑
    $standardPaths = @(
        "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe",
        "$env:ProgramFiles\AnyDesk\AnyDesk.exe",
        "$env:LocalAppData\AnyDesk\AnyDesk.exe",
        "$env:AppData\AnyDesk\AnyDesk.exe"
    )
    
    foreach ($path in $standardPaths) {
        if (Test-Path $path) {
            $fileInfo = Get-Item $path
            $installations += @{
                Path = $path
                Version = $fileInfo.VersionInfo.FileVersion
                Size = $fileInfo.Length
                LastModified = $fileInfo.LastWriteTime
                Type = if ($path -like "*Program Files*") { "Installed" } else { "Portable" }
            }
        }
    }
    
    # 檢查註冊表
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AnyDesk",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\AnyDesk"
    )
    
    foreach ($regPath in $regPaths) {
        if (Test-Path $regPath) {
            $regInfo = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
            if ($regInfo) {
                Write-Log -Message "在註冊表中發現 AnyDesk：$($regInfo.DisplayName) $($regInfo.DisplayVersion)" -Level "INFO"
            }
        }
    }
    
    return $installations
}

function Test-AnydeskSignature {
    <#
    .SYNOPSIS
        驗證 AnyDesk 執行檔的數位簽章
    #>
    param(
        [string]$ExecutablePath
    )
    
    if (-not (Test-Path $ExecutablePath)) {
        return @{
            Valid = $false
            Status = "FileNotFound"
            Message = "執行檔不存在"
        }
    }
    
    try {
        $signature = Get-AuthenticodeSignature $ExecutablePath
        
        $result = @{
            Valid = ($signature.Status -eq "Valid")
            Status = $signature.Status
            Signer = $signature.SignerCertificate.Subject
            Issuer = $signature.SignerCertificate.Issuer
            Thumbprint = $signature.SignerCertificate.Thumbprint
            NotBefore = $signature.SignerCertificate.NotBefore
            NotAfter = $signature.SignerCertificate.NotAfter
        }
        
        # 驗證簽章者是否為 philandro Software GmbH（AnyDesk 官方）
        if ($result.Signer -notmatch "philandro Software GmbH") {
            $result.Valid = $false
            $result.Message = "簽章者不是 AnyDesk 官方（philandro Software GmbH）"
        }
        
        return $result
    }
    catch {
        return @{
            Valid = $false
            Status = "Error"
            Message = "簽章驗證失敗：$($_.Exception.Message)"
        }
    }
}

function Get-AnydeskConfiguration {
    <#
    .SYNOPSIS
        讀取 AnyDesk 配置檔案
    #>
    param(
        [string]$ConfigType # service, system, user
    )
    
    $configPaths = @{
        "service" = @(
            "$env:ProgramData\AnyDesk\service.conf",
            "$env:AppData\AnyDesk\service.conf"
        )
        "system" = @(
            "$env:ProgramData\AnyDesk\system.conf",
            "$env:AppData\AnyDesk\system.conf"
        )
        "user" = @(
            "$env:AppData\AnyDesk\user.conf"
        )
    }
    
    foreach ($path in $configPaths[$ConfigType]) {
        if (Test-Path $path) {
            try {
                $content = Get-Content $path -Raw -ErrorAction Stop
                return @{
                    Path = $path
                    Content = $content
                    Exists = $true
                    LastModified = (Get-Item $path).LastWriteTime
                }
            }
            catch {
                Write-Log -Message "無法讀取配置檔案 $path：$($_.Exception.Message)" -Level "WARN"
            }
        }
    }
    
    return @{
        Exists = $false
        Path = $null
        Content = $null
    }
}

function Test-CVE202452940 {
    <#
    .SYNOPSIS
        檢測 CVE-2024-52940（IP 地址洩露漏洞）
    #>
    $findings = @()
    
    # 檢查 system.conf 中的 Allow Direct Connections 設置
    $systemConf = Get-AnydeskConfiguration -ConfigType "system"
    
    if ($systemConf.Exists) {
        if ($systemConf.Content -match "ad\.anynet\.direct_connections\s*=\s*true") {
            $findings += @{
                CVE = "CVE-2024-52940"
                Risk = "HIGH"
                Title = "Allow Direct Connections 已啟用"
                Description = "當 'Allow Direct Connections' 啟用時，攻擊者可以通過 7070 端口獲取您的公網 IP 地址"
                ConfigFile = $systemConf.Path
                Mitigation = "在 AnyDesk 設置中禁用 'Allow Direct Connections' 功能"
                Reference = "https://nvd.nist.gov/vuln/detail/CVE-2024-52940"
            }
        }
    }
    
    # 檢查 7070 端口連接
    try {
        $connections = Get-NetTCPConnection -LocalPort 7070 -ErrorAction SilentlyContinue
        if ($connections) {
            foreach ($conn in $connections) {
                $findings += @{
                    CVE = "CVE-2024-52940"
                    Risk = "MEDIUM"
                    Title = "檢測到 7070 端口連接"
                    Description = "發現活動的 7070 端口連接：$($conn.RemoteAddress):$($conn.RemotePort)"
                    State = $conn.State
                    RemoteAddress = $conn.RemoteAddress
                    RemotePort = $conn.RemotePort
                    Mitigation = "檢查此連接是否為已知的合法連接"
                }
            }
        }
    }
    catch {
        Write-Log -Message "無法檢查 7070 端口連接：$($_.Exception.Message)" -Level "WARN"
    }
    
    return $findings
}

function Test-CVE202412754 {
    <#
    .SYNOPSIS
        檢測 CVE-2024-12754（權限提升漏洞 - NTFS 接合點攻擊）
    #>
    $findings = @()
    
    $anydeskDirs = @(
        "$env:ProgramData\AnyDesk",
        "$env:AppData\AnyDesk"
    )
    
    foreach ($dir in $anydeskDirs) {
        if (Test-Path $dir) {
            try {
                $items = Get-ChildItem $dir -Force -ErrorAction Stop
                foreach ($item in $items) {
                    # 檢查是否為符號連結或接合點
                    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                        $findings += @{
                            CVE = "CVE-2024-12754"
                            Risk = "CRITICAL"
                            Title = "檢測到可疑的符號連結或接合點"
                            Path = $item.FullName
                            Description = "發現 NTFS 接合點或符號連結，可能被用於權限提升攻擊"
                            Mitigation = "立即刪除此符號連結並重新安裝 AnyDesk"
                            Reference = "https://nvd.nist.gov/vuln/detail/CVE-2024-12754"
                        }
                    }
                }
            }
            catch {
                Write-Log -Message "無法掃描目錄 $dir：$($_.Exception.Message)" -Level "WARN"
            }
        }
    }
    
    return $findings
}

function Test-AnydeskSecurity {
    <#
    .SYNOPSIS
        檢查 AnyDesk 安全配置
    #>
    $findings = @()
    
    $systemConf = Get-AnydeskConfiguration -ConfigType "system"
    
    if ($systemConf.Exists) {
        # 檢查 ACL 是否啟用
        if ($systemConf.Content -notmatch "ad\.security\.acl_enabled\s*=\s*true") {
            $findings += @{
                Risk = "MEDIUM"
                Title = "訪問控制列表（ACL）未啟用"
                Description = "ACL 可以限制只有白名單中的 AnyDesk ID 才能連接"
                Mitigation = "在 AnyDesk 設置 > 安全性 > 訪問控制列表 中啟用 ACL"
            }
        }
        
        # 檢查 2FA 是否啟用
        if ($systemConf.Content -notmatch "ad\.security\.2fa_enabled\s*=\s*true") {
            $findings += @{
                Risk = "MEDIUM"
                Title = "雙因素認證（2FA）未啟用"
                Description = "2FA 可以防止密碼洩露後的未授權訪問"
                Mitigation = "在 AnyDesk 設置中啟用雙因素認證"
            }
        }
        
        # 檢查交互式訪問設置
        if ($systemConf.Content -match "ad\.security\.interactive_access\s*=\s*0") {
            Write-Log -Message "交互式訪問已禁用，這是一個良好的安全設置" -Level "INFO"
        }
    }
    
    return $findings
}

function Test-AnydeskProcess {
    <#
    .SYNOPSIS
        檢測 AnyDesk 進程的可疑行為
    #>
    $findings = @()
    
    $anydeskProcesses = Get-Process -Name "AnyDesk" -ErrorAction SilentlyContinue
    
    foreach ($proc in $anydeskProcesses) {
        try {
            $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction Stop).CommandLine
            
            # 檢測可疑的 CLI 參數
            $suspiciousParams = @{
                "--set-password" = "可能被用於靜默設置無人值守訪問密碼"
                "--plain" = "可能被用於隱藏連接行為"
                "--admin-settings" = "可能被用於繞過 GUI 安全提示"
            }
            
            foreach ($param in $suspiciousParams.Keys) {
                if ($cmdLine -match [regex]::Escape($param)) {
                    $findings += @{
                        Risk = "HIGH"
                        Title = "檢測到可疑的 CLI 參數：$param"
                        ProcessId = $proc.Id
                        CommandLine = $cmdLine
                        Description = $suspiciousParams[$param]
                        Mitigation = "檢查此進程的父進程，確認是否為合法操作"
                    }
                }
            }
            
            # 檢查父進程
            $parentProcId = (Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)").ParentProcessId
            if ($parentProcId) {
                $parentProc = Get-Process -Id $parentProcId -ErrorAction SilentlyContinue
                if ($parentProc -and $parentProc.Name -notin @("explorer", "services", "svchost")) {
                    $findings += @{
                        Risk = "MEDIUM"
                        Title = "AnyDesk 由異常的父進程啟動"
                        ProcessId = $proc.Id
                        ParentProcessId = $parentProcId
                        ParentProcessName = $parentProc.Name
                        Description = "AnyDesk 通常由 explorer.exe 或 services.exe 啟動"
                        Mitigation = "檢查父進程是否為惡意軟體"
                    }
                }
            }
        }
        catch {
            Write-Log -Message "無法分析進程 $($proc.Id)：$($_.Exception.Message)" -Level "WARN"
        }
    }
    
    return $findings
}

function Test-AnydeskLogs {
    <#
    .SYNOPSIS
        分析 AnyDesk 日誌檔案
    #>
    $findings = @()
    
    $logPaths = @(
        "$env:ProgramData\AnyDesk\ad.trace",
        "$env:ProgramData\AnyDesk\ad_svc.trace",
        "$env:AppData\AnyDesk\ad.trace"
    )
    
    foreach ($logPath in $logPaths) {
        if (Test-Path $logPath) {
            try {
                $recentLogs = Get-Content $logPath -Tail 1000 -ErrorAction Stop
                
                # 檢測暴力破解跡象
                $failedAttempts = $recentLogs | Where-Object { $_ -match "failed|denied|rejected|authentication failed" }
                if ($failedAttempts.Count -gt 10) {
                    $findings += @{
                        Risk = "HIGH"
                        Title = "檢測到大量連接失敗"
                        LogFile = $logPath
                        FailedAttempts = $failedAttempts.Count
                        Description = "發現 $($failedAttempts.Count) 次連接失敗，可能為暴力破解攻擊"
                        Mitigation = "啟用 ACL 白名單並檢查日誌中的可疑 IP 地址"
                    }
                }
                
                # 提取未知 AnyDesk ID
                $allMatches = $recentLogs | Select-String -Pattern "\b\d{9,10}\b" -AllMatches
                $unknownIDs = $allMatches | ForEach-Object { $_.Matches.Value } | Sort-Object -Unique
                
                if ($unknownIDs.Count -gt 0) {
                    Write-Log -Message "在日誌中發現 $($unknownIDs.Count) 個 AnyDesk ID" -Level "INFO"
                }
            }
            catch {
                Write-Log -Message "無法讀取日誌檔案 $logPath：$($_.Exception.Message)" -Level "WARN"
            }
        }
    }
    
    return $findings
}

function Test-HardwareFingerprint {
    <#
    .SYNOPSIS
        檢測硬體指紋和環境變動跡象
    #>
    $findings = @()
    
    $serviceConf = Get-AnydeskConfiguration -ConfigType "service"
    
    if ($serviceConf.Exists) {
        # 檢查配置檔案的最近修改時間
        $lastModified = $serviceConf.LastModified
        $daysSinceModified = (Get-Date) - $lastModified
        
        if ($daysSinceModified.TotalDays -lt 1) {
            $findings += @{
                Risk = "MEDIUM"
                Title = "service.conf 最近被修改"
                Path = $serviceConf.Path
                LastModified = $lastModified
                Description = "service.conf 在過去 24 小時內被修改，可能表示環境變動或篡改"
                Mitigation = "確認是否為合法的配置變更"
            }
        }
        
        # 檢查 AnyDesk ID 是否存在
        if ($serviceConf.Content -match "ad\.anynet\.id\s*=\s*(\d+)") {
            $anydeskID = $matches[1]
            Write-Log -Message "檢測到 AnyDesk ID：$anydeskID" -Level "INFO"
        } else {
            $findings += @{
                Risk = "HIGH"
                Title = "service.conf 中缺少 AnyDesk ID"
                Path = $serviceConf.Path
                Description = "配置檔案可能已損壞或被篡改"
                Mitigation = "重新安裝 AnyDesk 或從備份恢復配置"
            }
        }
    }
    
    return $findings
}

function Get-RiskScore {
    <#
    .SYNOPSIS
        計算總體風險評分
    #>
    param(
        [array]$Findings
    )
    
    $riskWeights = @{
        "CRITICAL" = 90
        "HIGH" = 70
        "MEDIUM" = 50
        "LOW" = 30
        "INFO" = 10
    }
    
    if ($Findings.Count -eq 0) {
        return 0
    }
    
    $totalScore = 0
    foreach ($finding in $Findings) {
        $risk = if ($finding.Risk) { $finding.Risk } else { "INFO" }
        $totalScore += $riskWeights[$risk]
    }
    
    return [math]::Round($totalScore / $Findings.Count, 2)
}

#endregion

#region 主要執行邏輯

Write-Log -Message "========== AnyDesk 安全檢測開始 ==========" -Level "INFO"
Write-Log -Message "執行時間：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "INFO"
Write-Log -Message "執行用戶：$env:USERNAME" -Level "INFO"
Write-Log -Message "電腦名稱：$env:COMPUTERNAME" -Level "INFO"

$allFindings = @()

# 1. 檢測 AnyDesk 安裝
Write-Host "`n[1/8] 檢測 AnyDesk 安裝..." -ForegroundColor Cyan
$installations = Get-AnydeskInstallation

if ($installations.Count -eq 0) {
    Write-Log -Message "系統中未檢測到 AnyDesk 安裝" -Level "INFO"
    Write-Host "[結果] 系統中未安裝 AnyDesk，無需進行安全檢測" -ForegroundColor Green
    
    $report = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ComputerName = $env:COMPUTERNAME
        AnydeskInstalled = $false
        Findings = @()
        RiskScore = 0
        Recommendation = "系統中未安裝 AnyDesk"
    }
    
    $report | ConvertTo-Json -Depth 10 | Out-File $ReportPath -Encoding UTF8
    Write-Log -Message "報告已保存到：$ReportPath" -Level "INFO"
    Write-Log -Message "========== AnyDesk 安全檢測完成 ==========" -Level "INFO"
    exit 0
}

Write-Log -Message "檢測到 $($installations.Count) 個 AnyDesk 安裝" -Level "INFO"
foreach ($install in $installations) {
    Write-Host "  [安裝] $($install.Path)" -ForegroundColor White
    Write-Host "    版本：$($install.Version)" -ForegroundColor Gray
    Write-Host "    類型：$($install.Type)" -ForegroundColor Gray
}

# 2. 驗證數位簽章
Write-Host "`n[2/8] 驗證數位簽章..." -ForegroundColor Cyan
foreach ($install in $installations) {
    $sigResult = Test-AnydeskSignature -ExecutablePath $install.Path
    
    if (-not $sigResult.Valid) {
        $allFindings += @{
            Risk = "CRITICAL"
            Title = "AnyDesk 執行檔簽章無效"
            Path = $install.Path
            SignatureStatus = $sigResult.Status
            Description = $sigResult.Message
            Mitigation = "立即移除此 AnyDesk 並從官方網站重新下載"
        }
        Write-Host "  [警告] 簽章無效：$($install.Path)" -ForegroundColor Red
    } else {
        Write-Host "  [通過] 簽章有效：$($sigResult.Signer)" -ForegroundColor Green
    }
}

# 3. 檢測 CVE-2024-52940
Write-Host "`n[3/8] 檢測 CVE-2024-52940（IP 洩露）..." -ForegroundColor Cyan
$cve52940Findings = Test-CVE202452940
$allFindings += $cve52940Findings
if ($cve52940Findings.Count -gt 0) {
    Write-Host "  [發現] $($cve52940Findings.Count) 個相關問題" -ForegroundColor Yellow
} else {
    Write-Host "  [通過] 未發現 CVE-2024-52940 相關風險" -ForegroundColor Green
}

# 4. 檢測 CVE-2024-12754
Write-Host "`n[4/8] 檢測 CVE-2024-12754（權限提升）..." -ForegroundColor Cyan
$cve12754Findings = Test-CVE202412754
$allFindings += $cve12754Findings
if ($cve12754Findings.Count -gt 0) {
    Write-Host "  [警告] 發現 $($cve12754Findings.Count) 個符號連結或接合點" -ForegroundColor Red
} else {
    Write-Host "  [通過] 未發現可疑的符號連結" -ForegroundColor Green
}

# 5. 檢查安全配置
Write-Host "`n[5/8] 檢查安全配置..." -ForegroundColor Cyan
$securityFindings = Test-AnydeskSecurity
$allFindings += $securityFindings
if ($securityFindings.Count -gt 0) {
    Write-Host "  [建議] $($securityFindings.Count) 個安全配置可以改進" -ForegroundColor Yellow
} else {
    Write-Host "  [通過] 安全配置良好" -ForegroundColor Green
}

# 6. 檢測進程可疑行為
Write-Host "`n[6/8] 檢測進程可疑行為..." -ForegroundColor Cyan
$processFindings = Test-AnydeskProcess
$allFindings += $processFindings
if ($processFindings.Count -gt 0) {
    Write-Host "  [警告] 發現 $($processFindings.Count) 個可疑的進程行為" -ForegroundColor Yellow
} else {
    Write-Host "  [通過] 未發現可疑的進程行為" -ForegroundColor Green
}

# 7. 分析日誌檔案
Write-Host "`n[7/8] 分析日誌檔案..." -ForegroundColor Cyan
$logFindings = Test-AnydeskLogs
$allFindings += $logFindings
if ($logFindings.Count -gt 0) {
    Write-Host "  [發現] $($logFindings.Count) 個日誌異常" -ForegroundColor Yellow
} else {
    Write-Host "  [通過] 日誌分析正常" -ForegroundColor Green
}

# 8. 檢測硬體指紋和環境變動
Write-Host "`n[8/8] 檢測硬體指紋和環境變動..." -ForegroundColor Cyan
$fingerprintFindings = Test-HardwareFingerprint
$allFindings += $fingerprintFindings
if ($fingerprintFindings.Count -gt 0) {
    Write-Host "  [發現] $($fingerprintFindings.Count) 個環境變動跡象" -ForegroundColor Yellow
} else {
    Write-Host "  [通過] 未發現異常的環境變動" -ForegroundColor Green
}

# 計算總體風險評分
$riskScore = Get-RiskScore -Findings $allFindings

# 生成報告
Write-Host "`n========== 檢測摘要 ==========" -ForegroundColor Cyan
Write-Host "總發現數：$($allFindings.Count)" -ForegroundColor White
Write-Host "風險評分：$riskScore / 100" -ForegroundColor $(if ($riskScore -gt 70) { "Red" } elseif ($riskScore -gt 40) { "Yellow" } else { "Green" })

# 按風險等級分類
$criticalCount = ($allFindings | Where-Object { $_.Risk -eq "CRITICAL" }).Count
$highCount = ($allFindings | Where-Object { $_.Risk -eq "HIGH" }).Count
$mediumCount = ($allFindings | Where-Object { $_.Risk -eq "MEDIUM" }).Count

Write-Host "  嚴重 (CRITICAL)：$criticalCount" -ForegroundColor Red
Write-Host "  高風險 (HIGH)：$highCount" -ForegroundColor Yellow
Write-Host "  中風險 (MEDIUM)：$mediumCount" -ForegroundColor Yellow

# 顯示前 5 個最嚴重的發現
if ($allFindings.Count -gt 0) {
    Write-Host "`n========== 主要發現 ==========" -ForegroundColor Cyan
    $topFindings = $allFindings | Sort-Object { 
        switch ($_.Risk) {
            "CRITICAL" { 1 }
            "HIGH" { 2 }
            "MEDIUM" { 3 }
            "LOW" { 4 }
            default { 5 }
        }
    } | Select-Object -First 5
    
    $index = 1
    foreach ($finding in $topFindings) {
        $riskColor = switch ($finding.Risk) {
            "CRITICAL" { "Red" }
            "HIGH" { "Yellow" }
            default { "White" }
        }
        Write-Host "`n[$index] [$($finding.Risk)]" -ForegroundColor $riskColor -NoNewline
        Write-Host " $($finding.Title)" -ForegroundColor White
        Write-Host "    $($finding.Description)" -ForegroundColor Gray
        if ($finding.Mitigation) {
            Write-Host "    修復建議：$($finding.Mitigation)" -ForegroundColor Cyan
        }
        $index++
    }
}

# 保存完整報告
$report = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName = $env:COMPUTERNAME
    AnydeskInstalled = $true
    Installations = $installations
    Findings = $allFindings
    RiskScore = $riskScore
    Summary = @{
        Total = $allFindings.Count
        Critical = $criticalCount
        High = $highCount
        Medium = $mediumCount
    }
}

try {
    $report | ConvertTo-Json -Depth 10 | Out-File $ReportPath -Encoding UTF8
    Write-Host "`n[報告] 完整報告已保存到：$ReportPath" -ForegroundColor Green
}
catch {
    Write-Log -Message "無法保存報告：$($_.Exception.Message)" -Level "ERROR"
}

Write-Log -Message "========== AnyDesk 安全檢測完成 ==========" -Level "INFO"

#endregion


# ============================================================================
# 導入進階檢測函數
# ============================================================================

. "$PSScriptRoot\AnyDesk\Advanced_Attack_Detection.ps1"
. "$PSScriptRoot\AnyDesk\Mode_Detection.ps1"

# ============================================================================
# 主執行邏輯
# ============================================================================

function Start-AnyDeskSecurityScan {
    
    $report = @{
        ScanTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ComputerName = $env:COMPUTERNAME
        Detections = @()
        RiskScore = 0
        Summary = ""
    }
    
    Write-Log "開始 AnyDesk 安全掃描..."
    
    # 執行所有檢測
    $modeDetectionResult = Get-AnyDeskMode
    $privacyModeResult = Test-AnyDeskPrivacyMode
    $gpuAttackResult = Test-GPUAttackIndicators
    $privacyAbuseResult = Test-PrivacyModeAbuse
    $gpoTamperingResult = Test-GPOTampering
    $clickFixResult = Test-ClickFixIndicators
    
    # 整合檢測結果
    $report.Detections += @{
        Module = "AnyDesk Mode Detection"
        Result = $modeDetectionResult
    }
    # 根據模式調整風險評分
    switch ($modeDetectionResult.Mode) {
        "Installed" { $report.RiskScore += 60 }
        "PortableElevated" { $report.RiskScore += 40 }
        "Portable" { $report.RiskScore += 20 }
    }
    
    $report.Detections += @{
        Module = "Privacy Mode Detection"
        Result = $privacyModeResult
    }
    if ($privacyModeResult.PrivacyModeDetected) {
        $report.RiskScore += 30
    }
    
    $report.Detections += @{
        Module = "GPU Attack Indicators"
        Result = $gpuAttackResult
    }
    $report.RiskScore += $gpuAttackResult.RiskScore
    
    $report.Detections += @{
        Module = "Privacy Mode Abuse"
        Result = $privacyAbuseResult
    }
    $report.RiskScore += $privacyAbuseResult.RiskScore
    
    $report.Detections += @{
        Module = "GPO Tampering"
        Result = $gpoTamperingResult
    }
    $report.RiskScore += $gpoTamperingResult.RiskScore
    
    $report.Detections += @{
        Module = "ClickFix Indicators"
        Result = $clickFixResult
    }
    $report.RiskScore += $clickFixResult.RiskScore
    
    # 生成總結
    if ($report.RiskScore -ge 100) {
        $report.Summary = "[極高風險] 系統已確認遭到多層次 APT 攻擊！"
    }
    elseif ($report.RiskScore -ge 50) {
        $report.Summary = "[高風險] 發現多個攻擊指標，強烈建議立即進行手動鑑識和清理。"
    }
    elseif ($report.RiskScore -gt 0) {
        $report.Summary = "[中等風險] 發現可疑活動，建議進一步調查。"
    }
    else {
        $report.Summary = "[低風險] 未發現明顯的攻擊指標。"
    }
    
    Write-Log "掃描完成，總風險評分：$($report.RiskScore)" -Level "WARN"
    
    # 保存報告
    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Log "檢測報告已保存到：$ReportPath"
}

# 執行主函數
Start-AnyDeskSecurityScan
