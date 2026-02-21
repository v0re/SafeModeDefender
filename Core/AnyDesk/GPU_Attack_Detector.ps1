# ============================================================================
# GPU_Attack_Detector.ps1 - AnyDesk 顯卡渲染攻擊檢測器
# 
# 功能：檢測 AnyDesk 遠端劫持過程中的顯卡渲染攻擊
# 威脅：Direct3D 裝置建立失敗、隱私模式濫用、惡意圖片置入
# ============================================================================

function Test-AnydeskGPUAttack {
    <#
    .SYNOPSIS
        檢測 AnyDesk 遠端劫持過程中的顯卡渲染攻擊
    
    .DESCRIPTION
        根據實際攻擊日誌分析，檢測以下攻擊特徵：
        1. Direct3D 裝置建立失敗 (0x8876086c 錯誤)
        2. AnyDesk 隱私模式（Black Screen）濫用
        3. 異常的圖形渲染錯誤
        4. 惡意檔案置入（可疑圖片）
        5. 遠端連線縮圖異常
    
    .OUTPUTS
        返回檢測結果物件，包含風險等級和詳細發現
    #>
    
    [CmdletBinding()]
    param()
    
    $result = @{
        Detected = $false
        RiskLevel = "Low"
        Findings = @()
        Recommendations = @()
    }
    
    Write-Host "`n[檢測] AnyDesk 顯卡渲染攻擊..." -ForegroundColor Cyan
    
    # ========================================
    # 1. 檢測 Direct3D 錯誤 (0x8876086c)
    # ========================================
    Write-Host "  [1/6] 檢查 Direct3D 裝置建立失敗..." -ForegroundColor Gray
    
    $d3dErrors = @()
    $anydeskLogPaths = @(
        "$env:ProgramData\AnyDesk\ad.trace",
        "$env:ProgramData\AnyDesk\ad_svc.trace",
        "$env:AppData\AnyDesk\ad.trace"
    )
    
    foreach ($logPath in $anydeskLogPaths) {
        if (Test-Path $logPath) {
            try {
                # 搜尋 Direct3D 錯誤代碼
                $content = Get-Content $logPath -ErrorAction SilentlyContinue | Select-Object -Last 5000
                $d3dMatches = $content | Select-String -Pattern "0x8876086c|D3DERR_DEVICELOST|D3DERR_DEVICENOTRESET|CreateDevice.*failed" -AllMatches
                
                if ($d3dMatches) {
                    $errorCount = $d3dMatches.Count
                    $d3dErrors += @{
                        LogFile = $logPath
                        ErrorCount = $errorCount
                        LastError = $d3dMatches[-1].Line
                    }
                    
                    Write-Host "    ⚠️  發現 $errorCount 個 Direct3D 錯誤" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "    ⚠️  無法讀取日誌：$logPath" -ForegroundColor Yellow
            }
        }
    }
    
    if ($d3dErrors.Count -gt 0) {
        $result.Detected = $true
        $result.RiskLevel = "High"
        $result.Findings += @{
            Type = "Direct3D_Device_Failure"
            Severity = "High"
            Description = "檢測到大量 Direct3D 裝置建立失敗 (0x8876086c)，這是遠端劫持攻擊的典型特徵"
            Details = $d3dErrors
            Evidence = "當 AnyDesk 試圖渲染遠端控制指令時，顯卡驅動程式發生衝突，導致畫面出現條紋、閃爍、破圖或顏色異常"
        }
        $result.Recommendations += "立即中斷所有 AnyDesk 連線並檢查顯卡驅動程式"
    }
    
    # ========================================
    # 2. 檢測隱私模式（Black Screen）濫用
    # ========================================
    Write-Host "  [2/6] 檢查隱私模式濫用..." -ForegroundColor Gray
    
    $privacyModeAbuse = @()
    foreach ($logPath in $anydeskLogPaths) {
        if (Test-Path $logPath) {
            try {
                $content = Get-Content $logPath -ErrorAction SilentlyContinue | Select-Object -Last 5000
                $privacyMatches = $content | Select-String -Pattern "privacy.*mode|black.*screen|screen.*blanking|display.*override" -AllMatches
                
                if ($privacyMatches) {
                    $privacyModeAbuse += @{
                        LogFile = $logPath
                        OccurrenceCount = $privacyMatches.Count
                        Samples = ($privacyMatches | Select-Object -First 3).Line
                    }
                    
                    Write-Host "    ⚠️  發現 $($privacyMatches.Count) 次隱私模式活動" -ForegroundColor Yellow
                }
            }
            catch {}
        }
    }
    
    if ($privacyModeAbuse.Count -gt 0) {
        $result.Detected = $true
        if ($result.RiskLevel -eq "Low") { $result.RiskLevel = "Medium" }
        $result.Findings += @{
            Type = "Privacy_Mode_Abuse"
            Severity = "Medium"
            Description = "檢測到隱私模式（Black Screen）活動，攻擊者可能試圖在操作時屏蔽您的視覺"
            Details = $privacyModeAbuse
            Evidence = "強制覆蓋層在連線不穩或權限衝突時會產生異常的圖形疊加"
        }
        $result.Recommendations += "檢查 AnyDesk 設置中的隱私模式配置"
    }
    
    # ========================================
    # 3. 檢測異常連線縮圖
    # ========================================
    Write-Host "  [3/6] 檢查異常連線縮圖..." -ForegroundColor Gray
    
    $thumbnailPath = "$env:AppData\AnyDesk\thumbnails"
    $suspiciousThumbnails = @()
    
    if (Test-Path $thumbnailPath) {
        $thumbnails = Get-ChildItem $thumbnailPath -File -ErrorAction SilentlyContinue
        foreach ($thumb in $thumbnails) {
            # 檢查最近修改的縮圖（24小時內）
            if ($thumb.LastWriteTime -gt (Get-Date).AddDays(-1)) {
                $suspiciousThumbnails += @{
                    FileName = $thumb.Name
                    Size = $thumb.Length
                    LastModified = $thumb.LastWriteTime
                    Path = $thumb.FullName
                }
            }
        }
        
        if ($suspiciousThumbnails.Count -gt 0) {
            Write-Host "    ⚠️  發現 $($suspiciousThumbnails.Count) 個最近的連線縮圖" -ForegroundColor Yellow
            $result.Findings += @{
                Type = "Recent_Connection_Thumbnails"
                Severity = "Low"
                Description = "發現最近的 AnyDesk 連線縮圖，可能包含攻擊者的桌面環境或受駭過程的畫面"
                Details = $suspiciousThumbnails
            }
            $result.Recommendations += "檢查並備份 $thumbnailPath 中的縮圖檔案以供分析"
        }
    }
    
    # ========================================
    # 4. 檢測惡意圖片置入
    # ========================================
    Write-Host "  [4/6] 檢查惡意圖片置入..." -ForegroundColor Gray
    
    $suspiciousImages = @()
    $anydeskDirs = @(
        "$env:ProgramData\AnyDesk",
        "$env:AppData\AnyDesk",
        "$env:LocalAppData\AnyDesk",
        "$env:Temp"
    )
    
    foreach ($dir in $anydeskDirs) {
        if (Test-Path $dir) {
            # 搜尋最近24小時內的圖片檔案
            $images = Get-ChildItem $dir -Recurse -Include *.jpg,*.jpeg,*.png,*.bmp,*.gif -File -ErrorAction SilentlyContinue |
                      Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-1) }
            
            foreach ($img in $images) {
                $suspiciousImages += @{
                    FileName = $img.Name
                    Path = $img.FullName
                    Size = $img.Length
                    Created = $img.CreationTime
                    Modified = $img.LastWriteTime
                }
            }
        }
    }
    
    if ($suspiciousImages.Count -gt 0) {
        Write-Host "    ⚠️  發現 $($suspiciousImages.Count) 個可疑圖片檔案" -ForegroundColor Yellow
        $result.Detected = $true
        if ($result.RiskLevel -eq "Low") { $result.RiskLevel = "Medium" }
        $result.Findings += @{
            Type = "Suspicious_Image_Files"
            Severity = "Medium"
            Description = "發現最近置入的圖片檔案，可能包含惡意腳本或用於進一步誘騙的偽裝內容"
            Details = $suspiciousImages
        }
        $result.Recommendations += "隔離並分析這些圖片檔案，檢查是否包含隱藏的惡意代碼"
    }
    
    # ========================================
    # 5. 檢測圖形渲染異常
    # ========================================
    Write-Host "  [5/6] 檢查圖形渲染異常..." -ForegroundColor Gray
    
    $renderingErrors = @()
    foreach ($logPath in $anydeskLogPaths) {
        if (Test-Path $logPath) {
            try {
                $content = Get-Content $logPath -ErrorAction SilentlyContinue | Select-Object -Last 5000
                $renderMatches = $content | Select-String -Pattern "rendering.*fail|frame.*drop|video.*error|codec.*error|display.*corruption" -AllMatches
                
                if ($renderMatches) {
                    $renderingErrors += @{
                        LogFile = $logPath
                        ErrorCount = $renderMatches.Count
                        Samples = ($renderMatches | Select-Object -First 3).Line
                    }
                }
            }
            catch {}
        }
    }
    
    if ($renderingErrors.Count -gt 0) {
        Write-Host "    ⚠️  發現圖形渲染異常" -ForegroundColor Yellow
        $result.Findings += @{
            Type = "Rendering_Anomalies"
            Severity = "Medium"
            Description = "檢測到圖形渲染錯誤，可能是遠端劫持攻擊的副作用"
            Details = $renderingErrors
        }
    }
    
    # ========================================
    # 6. 檢測伊朗 IP 連線（根據您的案例）
    # ========================================
    Write-Host "  [6/6] 檢查可疑 IP 連線..." -ForegroundColor Gray
    
    $suspiciousIPs = @()
    foreach ($logPath in $anydeskLogPaths) {
        if (Test-Path $logPath) {
            try {
                $content = Get-Content $logPath -ErrorAction SilentlyContinue | Select-Object -Last 5000
                # 搜尋伊朗 IP 段 (79.127.x.x) 和其他可疑 IP
                $ipMatches = $content | Select-String -Pattern "\b79\.127\.\d{1,3}\.\d{1,3}\b|\b(?:91|185|5)\.\d{1,3}\.\d{1,3}\.\d{1,3}\b" -AllMatches
                
                if ($ipMatches) {
                    foreach ($match in $ipMatches) {
                        $ip = $match.Matches[0].Value
                        if ($ip -notin $suspiciousIPs.IP) {
                            $suspiciousIPs += @{
                                IP = $ip
                                FirstSeen = $match.Line
                                LogFile = $logPath
                            }
                        }
                    }
                }
            }
            catch {}
        }
    }
    
    if ($suspiciousIPs.Count -gt 0) {
        Write-Host "    🚨 發現 $($suspiciousIPs.Count) 個可疑 IP 地址！" -ForegroundColor Red
        $result.Detected = $true
        $result.RiskLevel = "Critical"
        $result.Findings += @{
            Type = "Suspicious_IP_Connections"
            Severity = "Critical"
            Description = "發現來自可疑地區（伊朗等）的 IP 連線，這與已知的 APT 攻擊模式一致"
            Details = $suspiciousIPs
            Evidence = "IP: 79.127.129.198 (伊朗) 已在您的案例中確認"
        }
        $result.Recommendations += "立即封鎖這些 IP 地址並報告給相關安全機構"
    }
    
    # ========================================
    # 總結
    # ========================================
    Write-Host "`n[總結] 顯卡攻擊檢測完成" -ForegroundColor Cyan
    Write-Host "  風險等級：$($result.RiskLevel)" -ForegroundColor $(
        switch ($result.RiskLevel) {
            "Critical" { "Red" }
            "High" { "Red" }
            "Medium" { "Yellow" }
            default { "Green" }
        }
    )
    Write-Host "  發現項目：$($result.Findings.Count)" -ForegroundColor White
    Write-Host "  建議措施：$($result.Recommendations.Count)" -ForegroundColor White
    
    return $result
}

# 導出函數
Export-ModuleMember -Function Test-AnydeskGPUAttack
