#encoding: utf-8-with-bom
<#
.SYNOPSIS
    AnyDesk 運行模式檢測模組 - 檢測 AnyDesk 的三種運行模式

.DESCRIPTION
    本模組用於檢測 AnyDesk 的運行模式：
    1. 可攜式模式（Portable Mode）
    2. 帶 Elevation 的可攜式模式（Portable Mode with Elevation）
    3. 安裝模式（Installed Mode）
    
    每種模式都有不同的安全風險和持久性特徵。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-19
    參考：https://support.anydesk.com/docs/zh-hant/portable-vs-installed
#>

function Get-AnyDeskMode {
    <#
    .SYNOPSIS
        檢測 AnyDesk 的運行模式
    
    .DESCRIPTION
        檢測 AnyDesk 當前的運行模式，並返回詳細資訊
    
    .OUTPUTS
        返回包含以下資訊的 Hashtable：
        - Mode: 運行模式（Installed, PortableElevated, Portable, NotDetected）
        - RiskLevel: 風險等級（Critical, High, Medium, Low）
        - Details: 詳細資訊
        - Findings: 發現的問題清單
    #>
    
    $result = @{
        Mode = "NotDetected"
        RiskLevel = "Low"
        Details = @{}
        Findings = @()
    }
    
    # 檢查 AnyDesk 服務是否存在
    $service = Get-Service -Name "AnyDesk" -ErrorAction SilentlyContinue
    
    if ($service) {
        # 安裝模式（最危險）
        $result.Mode = "Installed"
        $result.RiskLevel = "Critical"
        $result.Details = @{
            ServiceName = $service.Name
            ServiceStatus = $service.Status
            ServiceStartType = $service.StartType
            ServicePath = (Get-WmiObject Win32_Service -Filter "Name='AnyDesk'").PathName
            ConfigPath = "$env:PROGRAMDATA\AnyDesk"
        }
        
        $result.Findings += @{
            Risk = "CRITICAL"
            Title = "檢測到 AnyDesk 安裝模式（Installed Mode）"
            Description = "AnyDesk 以服務形式運行，具有最高持久性和最大攻擊面"
            Details = @(
                "✅ 服務隨系統自動啟動",
                "✅ 後台持續運行",
                "✅ 無人值守訪問始終可用",
                "✅ 可與 UAC 提示互動",
                "✅ 支援遠端重啟",
                "🔴 攻擊持久性：極高",
                "🔴 檢測難度：困難"
            )
            Mitigation = "如果這是未經授權的安裝，請立即使用緊急清理腳本移除"
            ServiceInfo = @{
                Status = $service.Status
                StartType = $service.StartType
                Path = $result.Details.ServicePath
            }
        }
        
        # 檢查服務路徑是否可疑
        if ($result.Details.ServicePath -notmatch "Program Files|ProgramData") {
            $result.Findings += @{
                Risk = "CRITICAL"
                Title = "AnyDesk 服務路徑異常"
                Description = "服務路徑不在標準位置，可能是惡意安裝"
                Path = $result.Details.ServicePath
                Mitigation = "立即停止服務並進行完整的惡意軟體掃描"
            }
        }
        
        # 檢查配置檔案
        $configPath = "$env:PROGRAMDATA\AnyDesk\system.conf"
        if (Test-Path $configPath) {
            try {
                $config = Get-Content $configPath -Raw
                
                # 檢查無人值守訪問
                if ($config -match "ad\.security\.interactive_access\s*=\s*2") {
                    $result.Findings += @{
                        Risk = "CRITICAL"
                        Title = "檢測到無人值守訪問已啟用"
                        Description = "攻擊者可以隨時連接而無需使用者確認"
                        ConfigFile = $configPath
                        Mitigation = "在 AnyDesk 設置中禁用無人值守訪問"
                    }
                }
                
                # 檢查密碼設置
                if ($config -match "ad\.security\.pwd_hash") {
                    $result.Findings += @{
                        Risk = "HIGH"
                        Title = "檢測到已設置無人值守訪問密碼"
                        Description = "如果此密碼被攻擊者設置，他們可以隨時訪問系統"
                        ConfigFile = $configPath
                        Mitigation = "立即變更密碼或禁用無人值守訪問"
                    }
                }
            }
            catch {
                Write-Warning "無法讀取配置檔案：$($_.Exception.Message)"
            }
        }
        
        return $result
    }
    
    # 檢查 AnyDesk 進程
    $processes = Get-Process -Name "anydesk" -ErrorAction SilentlyContinue
    
    if (-not $processes) {
        $result.Mode = "NotDetected"
        $result.RiskLevel = "Low"
        $result.Details = @{
            Message = "未檢測到 AnyDesk 運行"
        }
        return $result
    }
    
    # 檢查進程權限和會話
    foreach ($proc in $processes) {
        try {
            # 獲取進程所有者
            $owner = (Get-WmiObject Win32_Process -Filter "ProcessId=$($proc.Id)").GetOwner()
            $isSystem = $owner.Domain -eq "NT AUTHORITY" -and $owner.User -eq "SYSTEM"
            
            # 獲取會話 ID
            $sessionId = $proc.SessionId
            
            # 檢查是否在 Session 0（系統會話）中運行
            if ($sessionId -eq 0 -or $isSystem) {
                # 帶 Elevation 的便攜式模式（危險）
                $result.Mode = "PortableElevated"
                $result.RiskLevel = "High"
                $result.Details = @{
                    ProcessId = $proc.Id
                    ProcessPath = $proc.Path
                    SessionId = $sessionId
                    Owner = "$($owner.Domain)\$($owner.User)"
                    IsSystem = $isSystem
                    ConfigPath = "$env:APPDATA\AnyDesk"
                }
                
                $result.Findings += @{
                    Risk = "HIGH"
                    Title = "檢測到帶 Elevation 的可攜式模式（Portable Mode with Elevation）"
                    Description = "AnyDesk 以提升權限運行，可以繞過 UAC 並在登入畫面運行"
                    Details = @(
                        "⚠️ 需要管理員權限",
                        "✅ 可與 UAC 提示互動",
                        "✅ 可在登入畫面運行",
                        "❌ 不隨系統自動啟動",
                        "❌ 使用者登出後連接中斷",
                        "🟠 攻擊持久性：中等",
                        "🟡 檢測難度：中等"
                    )
                    ProcessInfo = @{
                        PID = $proc.Id
                        Path = $proc.Path
                        SessionId = $sessionId
                        Owner = "$($owner.Domain)\$($owner.User)"
                    }
                    Mitigation = "檢查此進程是否為已知的合法使用，如果不是，請立即終止"
                }
                
                # 如果在 Session 0 中運行，這是非常可疑的
                if ($sessionId -eq 0) {
                    $result.Findings += @{
                        Risk = "CRITICAL"
                        Title = "AnyDesk 在 Session 0（系統會話）中運行"
                        Description = "這是非常可疑的行為，可能是攻擊者試圖在登入畫面攔截憑證"
                        SessionId = $sessionId
                        Mitigation = "立即終止此進程並進行完整的安全審計"
                    }
                }
            }
            else {
                # 可攜式模式（低風險）
                $result.Mode = "Portable"
                $result.RiskLevel = "Medium"
                $result.Details = @{
                    ProcessId = $proc.Id
                    ProcessPath = $proc.Path
                    SessionId = $sessionId
                    Owner = "$($owner.Domain)\$($owner.User)"
                    ConfigPath = "$env:APPDATA\AnyDesk"
                }
                
                $result.Findings += @{
                    Risk = "MEDIUM"
                    Title = "檢測到可攜式模式（Portable Mode）"
                    Description = "AnyDesk 以便攜版運行，風險相對較低但仍需注意"
                    Details = @(
                        "✅ 不需要管理員權限",
                        "❌ 無法與 UAC 提示互動",
                        "❌ 不隨系統自動啟動",
                        "❌ 使用者登出後連接中斷",
                        "🟡 攻擊持久性：低",
                        "🟢 檢測難度：容易"
                    )
                    ProcessInfo = @{
                        PID = $proc.Id
                        Path = $proc.Path
                        SessionId = $sessionId
                        Owner = "$($owner.Domain)\$($owner.User)"
                    }
                    Mitigation = "檢查此程式是否為您主動啟動，如果不是，請終止並刪除"
                }
            }
            
            # 檢查進程路徑是否可疑
            if ($proc.Path) {
                $suspiciousPaths = @(
                    "$env:TEMP",
                    "$env:PUBLIC",
                    "C:\Windows\Temp"
                )
                
                foreach ($suspPath in $suspiciousPaths) {
                    if ($proc.Path -like "$suspPath*") {
                        $result.Findings += @{
                            Risk = "HIGH"
                            Title = "AnyDesk 從可疑位置運行"
                            Description = "AnyDesk 從臨時目錄運行，這是典型的惡意行為"
                            Path = $proc.Path
                            Mitigation = "立即終止此進程並刪除檔案"
                        }
                        $result.RiskLevel = "High"
                    }
                }
                
                # 檢查數位簽章
                try {
                    $signature = Get-AuthenticodeSignature $proc.Path
                    if ($signature.Status -ne "Valid") {
                        $result.Findings += @{
                            Risk = "CRITICAL"
                            Title = "AnyDesk 執行檔簽章無效"
                            Description = "執行檔可能被篡改或為惡意軟體"
                            Path = $proc.Path
                            SignatureStatus = $signature.Status
                            Mitigation = "立即終止此進程並進行惡意軟體掃描"
                        }
                        $result.RiskLevel = "Critical"
                    }
                }
                catch {
                    Write-Warning "無法檢查數位簽章：$($_.Exception.Message)"
                }
            }
            
            # 檢查啟動項中是否有自動啟動
            $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
            if (Test-Path $startupPath) {
                $startupItems = Get-ChildItem $startupPath | Where-Object {
                    $_.Name -match "anydesk|remote|support"
                }
                
                if ($startupItems) {
                    $result.Findings += @{
                        Risk = "HIGH"
                        Title = "檢測到 AnyDesk 自動啟動項"
                        Description = "攻擊者可能設置了自動啟動以實現持久化"
                        StartupItems = $startupItems | ForEach-Object { $_.FullName }
                        Mitigation = "檢查這些啟動項是否為您設置，如果不是，請刪除"
                    }
                }
            }
            
        }
        catch {
            Write-Warning "無法檢查進程 $($proc.Id)：$($_.Exception.Message)"
        }
    }
    
    return $result
}

function Test-AnyDeskPrivacyMode {
    <#
    .SYNOPSIS
        檢測 AnyDesk 隱私模式（黑屏模式）的使用
    
    .DESCRIPTION
        檢測 AnyDesk 日誌中的隱私模式使用記錄
    #>
    
    $result = @{
        PrivacyModeDetected = $false
        Findings = @()
    }
    
    # 檢查日誌檔案
    $logPaths = @(
        "$env:APPDATA\AnyDesk\ad.trace",
        "$env:PROGRAMDATA\AnyDesk\ad.trace"
    )
    
    foreach ($logPath in $logPaths) {
        if (Test-Path $logPath) {
            try {
                # 讀取最近的日誌（最後 1000 行）
                $logContent = Get-Content $logPath -Tail 1000 -ErrorAction Stop
                
                # 搜尋隱私模式相關的關鍵字
                $privacyModeMatches = $logContent | Select-String -Pattern "privacy.*mode|black.*screen|screen.*privacy" -AllMatches
                
                if ($privacyModeMatches) {
                    $result.PrivacyModeDetected = $true
                    $result.Findings += @{
                        Risk = "HIGH"
                        Title = "檢測到隱私模式（黑屏模式）使用"
                        Description = "AnyDesk 隱私模式可以隱藏遠端操作，使受害者看不到攻擊者的行為"
                        LogFile = $logPath
                        MatchCount = $privacyModeMatches.Count
                        Mitigation = "檢查這些連接是否為已知的合法連接"
                    }
                }
                
                # 搜尋連接記錄
                $connectionMatches = $logContent | Select-String -Pattern "connection.*established|incoming.*connection" -AllMatches
                
                if ($connectionMatches) {
                    $result.Findings += @{
                        Risk = "MEDIUM"
                        Title = "檢測到遠端連接記錄"
                        Description = "發現 $($connectionMatches.Count) 條連接記錄"
                        LogFile = $logPath
                        ConnectionCount = $connectionMatches.Count
                        Mitigation = "審查這些連接是否為已知的合法連接"
                    }
                }
                
            }
            catch {
                Write-Warning "無法讀取日誌檔案 $logPath：$($_.Exception.Message)"
            }
        }
    }
    
    return $result
}

function Get-AnyDeskModeReport {
    <#
    .SYNOPSIS
        生成 AnyDesk 模式檢測報告
    
    .DESCRIPTION
        執行完整的 AnyDesk 模式檢測並生成報告
    #>
    
    param(
        [string]$ReportPath = "$env:USERPROFILE\Desktop\AnyDesk_Mode_Report.json"
    )
    
    Write-Host "`n========== AnyDesk 運行模式檢測 ==========" -ForegroundColor Cyan
    Write-Host "執行時間：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    
    # 檢測運行模式
    Write-Host "`n[1/2] 檢測 AnyDesk 運行模式..." -ForegroundColor Cyan
    $modeResult = Get-AnyDeskMode
    
    Write-Host "  [檢測結果] 模式：$($modeResult.Mode)" -ForegroundColor White
    Write-Host "  [風險等級] $($modeResult.RiskLevel)" -ForegroundColor $(
        switch ($modeResult.RiskLevel) {
            "Critical" { "Red" }
            "High" { "Yellow" }
            "Medium" { "Yellow" }
            default { "Green" }
        }
    )
    
    # 檢測隱私模式
    Write-Host "`n[2/2] 檢測隱私模式使用..." -ForegroundColor Cyan
    $privacyResult = Test-AnyDeskPrivacyMode
    
    if ($privacyResult.PrivacyModeDetected) {
        Write-Host "  [警告] 檢測到隱私模式使用！" -ForegroundColor Red
    } else {
        Write-Host "  [通過] 未檢測到隱私模式使用" -ForegroundColor Green
    }
    
    # 整合結果
    $allFindings = @()
    $allFindings += $modeResult.Findings
    $allFindings += $privacyResult.Findings
    
    # 生成報告
    $report = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ComputerName = $env:COMPUTERNAME
        Mode = $modeResult.Mode
        RiskLevel = $modeResult.RiskLevel
        ModeDetails = $modeResult.Details
        PrivacyModeDetected = $privacyResult.PrivacyModeDetected
        Findings = $allFindings
        Summary = @{
            TotalFindings = $allFindings.Count
            Critical = ($allFindings | Where-Object { $_.Risk -eq "CRITICAL" }).Count
            High = ($allFindings | Where-Object { $_.Risk -eq "HIGH" }).Count
            Medium = ($allFindings | Where-Object { $_.Risk -eq "MEDIUM" }).Count
        }
    }
    
    # 顯示摘要
    Write-Host "`n========== 檢測摘要 ==========" -ForegroundColor Cyan
    Write-Host "總發現數：$($report.Summary.TotalFindings)" -ForegroundColor White
    Write-Host "  嚴重 (CRITICAL)：$($report.Summary.Critical)" -ForegroundColor Red
    Write-Host "  高風險 (HIGH)：$($report.Summary.High)" -ForegroundColor Yellow
    Write-Host "  中風險 (MEDIUM)：$($report.Summary.Medium)" -ForegroundColor Yellow
    
    # 顯示主要發現
    if ($allFindings.Count -gt 0) {
        Write-Host "`n========== 主要發現 ==========" -ForegroundColor Cyan
        $topFindings = $allFindings | Sort-Object { 
            switch ($_.Risk) {
                "CRITICAL" { 1 }
                "HIGH" { 2 }
                "MEDIUM" { 3 }
                default { 4 }
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
    
    # 保存報告
    try {
        $report | ConvertTo-Json -Depth 10 | Out-File $ReportPath -Encoding UTF8
        Write-Host "`n[報告] 完整報告已保存到：$ReportPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "無法保存報告：$($_.Exception.Message)"
    }
    
    Write-Host "`n========== 檢測完成 ==========" -ForegroundColor Cyan
    
    return $report
}

# 如果直接執行此腳本，則運行報告生成
if ($MyInvocation.InvocationName -ne '.') {
    Get-AnyDeskModeReport
}
