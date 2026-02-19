# SafeModeDefender v2.0 - 完整防護矩陣

## 基於真實世界威脅情報的安全防護設計

**威脅情報來源：** Exploit-DB, Shodan, CVE Database, CISA KEV, 實際攻擊案例分析

**設計日期：** 2026-02-19

---

## 一、核心防護模塊設計（共 25 個專業級模塊）

### 類別 A：網路服務與端口安全（7 個模塊）

#### A1. SMB 服務安全強化模塊
**威脅來源：** CVE-2025-33073 (Windows 11 SMB Client RCE)
**防護目標：**
- 端口 445 (SMB)
- 端口 139 (NetBIOS)
- SMB 簽名強制執行
- SMB 版本降級攻擊防護

**檢測項目：**
1. SMB v1.0 是否已禁用
2. SMB 簽名是否強制啟用
3. 匿名存取是否已禁用
4. 網路共享權限審計
5. SMB 相關服務狀態（Server, Workstation, Browser）

**修復操作：**
- 完全禁用 SMB v1.0
- 強制 SMB 簽名（註冊表 + 本機策略）
- 禁用匿名存取
- 關閉不必要的網路共享
- 配置防火牆規則（僅限本機網路）

---

#### A2. RDP 服務安全強化模塊
**威脅來源：** CVE-2026-21533 (RDP 權限提升)
**防護目標：**
- 端口 3389 (RDP)
- RDP 服務配置安全
- 網路層級驗證 (NLA)

**檢測項目：**
1. RDP 服務是否啟用
2. NLA 是否強制啟用
3. 端口 3389 防火牆規則
4. RDP 連接日誌審計
5. 遠端桌面使用者群組成員

**修復操作：**
- 完全禁用 RDP（如不需要）
- 強制啟用 NLA
- 限制 RDP 存取 IP 範圍
- 啟用 RDP 連接日誌
- 移除不必要的遠端桌面使用者

---

#### A3. UPnP/SSDP 服務禁用模塊
**威脅來源：** Shodan 掃描數據，UPnP 常被用於內網滲透
**防護目標：**
- 端口 1900 (SSDP)
- 端口 2869 (UPnP)
- UPnP Device Host 服務

**檢測項目：**
1. SSDP Discovery 服務狀態
2. UPnP Device Host 服務狀態
3. 端口 1900/2869 監聽狀態
4. 防火牆 UPnP 規則

**修復操作：**
- 禁用 SSDP Discovery 服務
- 禁用 UPnP Device Host 服務
- 刪除相關防火牆規則
- 禁用 UPnP 註冊表項

---

#### A4. mDNS/Bonjour 服務禁用模塊
**威脅來源：** 端口 5353 常被用於 DNS 劫持和內網偵察
**防護目標：**
- 端口 5353 (mDNS)
- Bonjour 服務

**檢測項目：**
1. Bonjour 服務是否安裝
2. 端口 5353 監聽狀態
3. mDNS 防火牆規則
4. 相關第三方軟體（iTunes, Adobe 等）

**修復操作：**
- 卸載 Bonjour 服務
- 禁用端口 5353
- 刪除 mDNS 防火牆規則
- 清理相關註冊表項

---

#### A5. WinRM/PowerShell Remoting 安全模塊
**威脅來源：** 遠端管理服務常被用於橫向移動
**防護目標：**
- 端口 5985 (HTTP)
- 端口 5986 (HTTPS)
- WinRM 服務

**檢測項目：**
1. WinRM 服務狀態
2. PowerShell Remoting 配置
3. 端口 5985/5986 監聽狀態
4. WinRM 防火牆規則

**修復操作：**
- 禁用 WinRM 服務（如不需要）
- 禁用 PowerShell Remoting
- 刪除相關防火牆規則
- 清理 WinRM 配置

---

#### A6. LLMNR/NetBIOS-NS 禁用模塊
**威脅來源：** LLMNR/NetBIOS 中繼攻擊
**防護目標：**
- 端口 137 (NetBIOS Name Service)
- 端口 138 (NetBIOS Datagram)
- LLMNR 協議

**檢測項目：**
1. LLMNR 是否啟用
2. NetBIOS over TCP/IP 狀態
3. 相關防火牆規則

**修復操作：**
- 禁用 LLMNR（註冊表）
- 禁用 NetBIOS over TCP/IP
- 刪除相關防火牆規則

---

#### A7. 危險端口全面掃描與封鎖模塊
**威脅來源：** Shodan 掃描數據 + 實際攻擊案例
**防護目標：**
- 所有高危端口的監聽和防火牆狀態

**高危端口清單：**
```
21    - FTP
22    - SSH
23    - Telnet
25    - SMTP
53    - DNS
80    - HTTP
110   - POP3
135   - MS-RPC
137-139 - NetBIOS
143   - IMAP
443   - HTTPS
445   - SMB
1433  - MSSQL
1900  - UPnP/SSDP
3306  - MySQL
3389  - RDP
5353  - mDNS
5985-5986 - WinRM
8080  - HTTP Proxy
```

**檢測項目：**
1. 所有端口的監聽狀態
2. 監聽端口對應的進程
3. 防火牆規則審計
4. 未授權的監聽端口

**修復操作：**
- 生成完整的端口掃描報告
- 關閉未授權的監聽端口
- 配置防火牆規則（白名單模式）
- 記錄所有監聽進程

---

### 類別 B：系統權限與提權防護（5 個模塊）

#### B1. UAC 強化與繞過防護模塊
**威脅來源：** CVE-2026-21519 (權限提升)
**防護目標：**
- UAC 配置強化
- UAC 繞過技術檢測

**檢測項目：**
1. UAC 等級設定
2. 管理員批准模式
3. 已知 UAC 繞過技術檢測
4. 可疑的提權工具

**修復操作：**
- 設定 UAC 為最高等級
- 啟用管理員批准模式
- 檢測並移除 UAC 繞過工具
- 審計提權相關註冊表

---

#### B2. SYSTEM 權限異常檢測模塊
**威脅來源：** 使用者報告的 SYSTEM 權限異常
**防護目標：**
- SYSTEM 權限進程審計
- 服務權限異常檢測

**檢測項目：**
1. 所有 SYSTEM 權限進程
2. 可疑的 SYSTEM 服務
3. 服務配置異常
4. 服務執行檔路徑驗證

**修復操作：**
- 生成 SYSTEM 進程清單
- 檢測未簽名的 SYSTEM 服務
- 驗證服務執行檔數位簽章
- 移除可疑服務

---

#### B3. Token 竊取與模擬防護模塊
**威脅來源：** Token 竊取是常見的提權技術
**防護目標：**
- Token 權限審計
- SeDebugPrivilege 濫用檢測

**檢測項目：**
1. 具有 SeDebugPrivilege 的進程
2. Token 模擬行為檢測
3. 可疑的權限提升工具

**修復操作：**
- 審計特權 Token
- 限制 SeDebugPrivilege
- 檢測 Token 竊取工具

---

#### B4. 服務權限與 DLL 劫持防護模塊
**威脅來源：** 服務 DLL 劫持是常見的持久化技術
**防護目標：**
- 服務 DLL 路徑驗證
- 可寫服務目錄檢測

**檢測項目：**
1. 所有服務的 DLL 路徑
2. 服務目錄權限
3. 可疑的 DLL 劫持
4. 服務執行檔權限

**修復操作：**
- 驗證服務 DLL 簽章
- 修復服務目錄權限
- 移除可疑 DLL
- 強化服務路徑

---

#### B5. 計劃任務安全審計模塊
**威脅來源：** 計劃任務常被用於持久化和提權
**防護目標：**
- 計劃任務審計
- 可疑任務檢測

**檢測項目：**
1. 所有計劃任務清單
2. 任務執行權限
3. 任務觸發條件
4. 任務執行檔路徑

**修復操作：**
- 生成任務清單報告
- 檢測可疑任務
- 移除惡意任務
- 驗證任務簽章

---

### 類別 C：註冊表與持久化防護（4 個模塊）

#### C1. 註冊表自啟動項全面掃描模塊
**威脅來源：** 註冊表是最常見的持久化位置
**防護目標：**
- 所有自啟動註冊表項

**關鍵註冊表路徑：**
```
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce
HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce
HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders
HKLM\SYSTEM\CurrentControlSet\Services (ImagePath)
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon
```

**檢測項目：**
1. 所有自啟動項
2. 執行檔路徑驗證
3. 數位簽章驗證
4. 可疑的啟動項

**修復操作：**
- 生成完整啟動項清單
- 檢測未簽名項目
- 移除可疑啟動項
- 備份原始註冊表

---

#### C2. 註冊表替換符檢測模塊
**威脅來源：** 使用者報告的註冊表替換符攻擊
**防護目標：**
- Image File Execution Options
- 檔案關聯劫持

**檢測項目：**
1. IFEO Debugger 項
2. 檔案關聯異常
3. COM 劫持
4. AppInit_DLLs

**修復操作：**
- 檢測所有 Debugger 項
- 驗證檔案關聯
- 移除惡意替換符
- 修復 COM 註冊

---

#### C3. 註冊表權限異常檢測模塊
**威脅來源：** 註冊表權限異常可導致提權
**防護目標：**
- 關鍵註冊表項權限

**檢測項目：**
1. 關鍵註冊表項 ACL
2. Everyone 寫入權限
3. Users 組修改權限
4. 權限繼承異常

**修復操作：**
- 審計註冊表權限
- 修復異常權限
- 強化關鍵註冊表項
- 生成權限報告

---

#### C4. WMI 事件訂閱檢測模塊
**威脅來源：** WMI 事件訂閱是隱蔽的持久化技術
**防護目標：**
- WMI 事件過濾器
- WMI 事件消費者

**檢測項目：**
1. 所有 WMI 事件過濾器
2. 所有 WMI 事件消費者
3. 事件訂閱綁定
4. 可疑的 WMI 腳本

**修復操作：**
- 列舉所有 WMI 訂閱
- 檢測可疑訂閱
- 移除惡意訂閱
- 清理 WMI 儲存庫

---

### 類別 D：檔案系統與隱藏威脅（4 個模塊）

#### D1. 隱藏檔案與 ADS 掃描模塊
**威脅來源：** 隱藏檔案和備用數據流常用於隱藏惡意代碼
**防護目標：**
- 隱藏檔案
- 備用數據流 (ADS)
- 系統檔案偽裝

**檢測項目：**
1. 所有隱藏檔案
2. 所有 ADS
3. 系統目錄可疑檔案
4. 雙副檔名檔案

**修復操作：**
- 掃描所有隱藏檔案
- 列舉所有 ADS
- 檢測可疑檔案
- 移除惡意 ADS

---

#### D2. INI 檔案安全掃描模塊
**威脅來源：** 使用者報告的隱藏 INI 檔案威脅
**防護目標：**
- desktop.ini
- 其他配置 INI 檔案

**檢測項目：**
1. 所有 INI 檔案
2. INI 檔案內容掃描
3. 可疑指令檢測
4. INI 檔案權限

**修復操作：**
- 掃描所有 INI 檔案
- 檢測惡意指令
- 移除可疑 INI
- 修復 INI 權限

---

#### D3. 檔案權限異常檢測模塊
**威脅來源：** 使用者報告的檔案權限異常
**防護目標：**
- 系統目錄權限
- 使用者無法存取的檔案

**檢測項目：**
1. 系統目錄 ACL
2. Everyone 寫入權限
3. 使用者存取異常
4. 權限繼承問題

**修復操作：**
- 審計檔案權限
- 修復異常權限
- 生成權限報告
- 強化系統目錄

---

#### D4. 可疑執行檔與數位簽章驗證模塊
**威脅來源：** 未簽名或偽造簽章的執行檔
**防護目標：**
- 所有執行檔簽章驗證

**檢測項目：**
1. 系統目錄執行檔
2. 自啟動執行檔
3. 服務執行檔
4. 數位簽章驗證

**修復操作：**
- 掃描所有執行檔
- 驗證數位簽章
- 檢測未簽名檔案
- 生成簽章報告

---

### 類別 E：記憶體與漏洞防護（3 個模塊）

#### E1. 記憶體溢出漏洞緩解模塊
**威脅來源：** CVE-2025-24993, CVE-2025-26674 (緩衝區溢位)
**防護目標：**
- DEP (數據執行防止)
- ASLR (地址空間佈局隨機化)
- CFG (控制流防護)

**檢測項目：**
1. DEP 配置狀態
2. ASLR 啟用狀態
3. CFG 支援狀態
4. 記憶體保護設定

**修復操作：**
- 啟用 DEP（所有程式）
- 強制啟用 ASLR
- 啟用 CFG
- 配置記憶體保護

---

#### E2. 終端亂碼與記憶體溢出修復模塊
**威脅來源：** 使用者報告的終端亂碼和記憶體溢出
**防護目標：**
- 終端編碼設定
- 記憶體限制配置

**檢測項目：**
1. 終端編碼設定
2. 控制台緩衝區大小
3. 記憶體限制配置
4. 可疑的記憶體使用

**修復操作：**
- 設定 UTF-8 編碼
- 限制緩衝區大小
- 配置記憶體限制
- 修復終端設定

---

#### E3. 顯示卡渲染溢出防護模塊
**威脅來源：** 使用者報告的 AnyDesk 顯示卡渲染攻擊
**防護目標：**
- 顯示卡驅動安全
- 遠端桌面渲染設定

**檢測項目：**
1. 顯示卡驅動版本
2. 硬體加速設定
3. 遠端桌面渲染配置
4. 可疑的顯示卡進程

**修復操作：**
- 更新顯示卡驅動
- 禁用硬體加速（如需要）
- 限制遠端渲染
- 配置安全設定

---

### 類別 F：隱私權與遙測（2 個模塊）

#### F1. Windows 隱私權全面關閉模塊
**威脅來源：** 隱私權功能可能被濫用
**防護目標：**
- 所有隱私權相關功能

**關閉項目：**
1. 攝像頭存取
2. 麥克風存取
3. 位置服務
4. 診斷數據
5. 活動歷程記錄
6. 廣告 ID
7. 語音辨識
8. 筆跡與輸入
9. 帳戶資訊存取
10. 聯絡人存取

**修復操作：**
- 禁用所有隱私權功能
- 配置本機策略
- 修改註冊表
- 生成隱私權報告

---

#### F2. Windows 遙測與診斷禁用模塊
**威脅來源：** 遙測服務可能洩露資訊
**防護目標：**
- 遙測服務
- 診斷服務

**禁用服務：**
1. DiagTrack (Connected User Experiences and Telemetry)
2. dmwappushservice
3. WerSvc (Windows Error Reporting)
4. OneSyncSvc
5. PcaSvc (Program Compatibility Assistant)

**修復操作：**
- 禁用所有遙測服務
- 刪除遙測計劃任務
- 配置防火牆規則
- 清理遙測數據

---

### 類別 G：系統完整性與更新（3 個模塊）

#### G1. Windows Update 修復與強制啟用模塊
**威脅來源：** 使用者報告的 Windows Update 被組織禁用
**防護目標：**
- Windows Update 服務
- 更新策略限制

**檢測項目：**
1. Windows Update 服務狀態
2. 更新策略配置
3. 更新限制來源
4. WSUS 配置

**修復操作：**
- 啟用 Windows Update 服務
- 移除更新限制策略
- 清理 WSUS 配置
- 強制檢查更新

---

#### G2. 系統檔案完整性檢查模塊
**威脅來源：** 系統檔案被篡改
**防護目標：**
- 系統檔案完整性

**檢測項目：**
1. SFC 掃描
2. DISM 健康檢查
3. 系統檔案簽章
4. 關鍵系統檔案

**修復操作：**
- 執行 SFC /scannow
- 執行 DISM 修復
- 驗證系統檔案
- 生成完整性報告

---

#### G3. BIOS/UEFI 更新檢測與引導模塊
**威脅來源：** CVE-2025-3052 (UEFI Bootkit)
**防護目標：**
- BIOS/UEFI 版本檢測
- 更新引導

**檢測項目：**
1. 主機板型號
2. 當前 BIOS 版本
3. 最新 BIOS 版本
4. Secure Boot 狀態

**修復操作：**
- 檢測主機板型號
- 查詢最新 BIOS
- 下載 BIOS 更新（如有網路）
- 生成更新引導文件

**支援廠商：**
- ASUS
- MSI
- Gigabyte
- ASRock
- Dell
- HP
- Lenovo
- Acer

---

### 類別 H：環境變數與 Hosts（2 個模塊）

#### H1. 環境變數安全檢測模塊
**威脅來源：** PATH 劫持、DLL 搜尋順序攻擊
**防護目標：**
- PATH 環境變數
- 其他系統環境變數

**檢測項目：**
1. PATH 變數審計
2. 可寫目錄檢測
3. DLL 搜尋順序
4. 可疑的環境變數

**修復操作：**
- 審計 PATH 變數
- 移除可疑路徑
- 修復目錄權限
- 優化搜尋順序

---

#### H2. Hosts 檔案安全檢測模塊
**威脅來源：** DNS 劫持、惡意重定向
**防護目標：**
- C:\Windows\System32\drivers\etc\hosts

**檢測項目：**
1. Hosts 檔案內容
2. 可疑的域名映射
3. Hosts 檔案權限
4. Hosts 檔案備份

**修復操作：**
- 掃描 Hosts 檔案
- 檢測惡意條目
- 移除可疑映射
- 修復檔案權限

---

### 類別 I：防火牆與策略（3 個模塊）

#### I1. 交互式防火牆優化工具
**威脅來源：** 不必要的防火牆規則增加攻擊面
**防護目標：**
- 所有防火牆規則

**功能：**
1. 列舉所有防火牆規則
2. 按功能分類規則
3. 交互式詢問使用情況
4. 自動禁用不需要的規則

**規則分類：**
- 網路共享（SMB, 印表機）
- 遠端管理（RDP, WinRM）
- 媒體串流（DLNA, UPnP）
- 無線投影（Miracast）
- 檔案與印表機共享
- 核心網路功能
- 應用程式規則

**修復操作：**
- 生成規則清單
- 詢問使用情況
- 禁用不需要的規則
- 禁用相關服務
- 生成優化報告

---

#### I2. 本機安全策略強化模塊
**威脅來源：** 不安全的本機策略配置
**防護目標：**
- 本機安全策略

**強化項目：**
1. 密碼策略
2. 帳戶鎖定策略
3. 審計策略
4. 使用者權限指派
5. 安全選項

**修復操作：**
- 配置強密碼策略
- 啟用帳戶鎖定
- 啟用審計日誌
- 限制使用者權限
- 強化安全選項

---

#### I3. 網路登入方式檢查模塊
**威脅來源：** 使用者報告的網路登入異常
**防護目標：**
- 網路登入策略

**檢測項目：**
1. 允許網路登入的使用者
2. 拒絕網路登入的使用者
3. 遠端桌面使用者
4. 網路存取權限

**修復操作：**
- 審計網路登入權限
- 移除不必要的權限
- 配置拒絕策略
- 生成權限報告

---

## 二、工具架構設計

### 主程式：SafeModeDefender.bat
- UTF-8 編碼支援（chcp 65001）
- 管理員權限檢測
- 安全模式檢測
- 模塊選單系統
- 進度顯示
- 日誌記錄

### 模塊結構：
```
SafeModeDefender_v2/
├── SafeModeDefender.bat          # 主啟動器
├── Core/
│   ├── Main.ps1                  # 主控制腳本
│   ├── Logger.ps1                # 日誌模塊
│   ├── Utils.ps1                 # 工具函數
│   ├── NetworkSecurity/
│   │   ├── A1_SMB_Security.ps1
│   │   ├── A2_RDP_Security.ps1
│   │   ├── A3_UPnP_Disable.ps1
│   │   ├── A4_mDNS_Disable.ps1
│   │   ├── A5_WinRM_Security.ps1
│   │   ├── A6_LLMNR_Disable.ps1
│   │   └── A7_Port_Scanner.ps1
│   ├── PrivilegeEscalation/
│   │   ├── B1_UAC_Hardening.ps1
│   │   ├── B2_SYSTEM_Audit.ps1
│   │   ├── B3_Token_Protection.ps1
│   │   ├── B4_Service_Security.ps1
│   │   └── B5_ScheduledTask_Audit.ps1
│   ├── RegistryPersistence/
│   │   ├── C1_Autorun_Scanner.ps1
│   │   ├── C2_Registry_Hijack.ps1
│   │   ├── C3_Registry_Permissions.ps1
│   │   └── C4_WMI_Events.ps1
│   ├── FileSystem/
│   │   ├── D1_Hidden_Files.ps1
│   │   ├── D2_INI_Scanner.ps1
│   │   ├── D3_File_Permissions.ps1
│   │   └── D4_Digital_Signature.ps1
│   ├── MemoryProtection/
│   │   ├── E1_Memory_Mitigation.ps1
│   │   ├── E2_Terminal_Fix.ps1
│   │   └── E3_GPU_Protection.ps1
│   ├── Privacy/
│   │   ├── F1_Privacy_Disable.ps1
│   │   └── F2_Telemetry_Disable.ps1
│   ├── SystemIntegrity/
│   │   ├── G1_Windows_Update.ps1
│   │   ├── G2_System_Integrity.ps1
│   │   └── G3_BIOS_Update.ps1
│   ├── Environment/
│   │   ├── H1_Environment_Variables.ps1
│   │   └── H2_Hosts_File.ps1
│   └── FirewallPolicy/
│       ├── I1_Firewall_Optimizer.ps1
│       ├── I2_Security_Policy.ps1
│       └── I3_Network_Logon.ps1
├── Batch/                        # 批次檔備用方案
│   └── (對應的 .bat 檔案)
├── Manuals/                      # 操作手冊
│   └── (對應的 .md 檔案)
├── Config/
│   ├── settings.ini              # 配置檔案
│   └── whitelist.txt             # 白名單
├── Logs/                         # 日誌目錄
├── Reports/                      # 報告目錄
└── README.md                     # 完整說明文件
```

---

## 三、開發標準

### 編碼標準：
- 所有檔案使用 UTF-8 with BOM
- 批次檔使用 `chcp 65001`
- PowerShell 使用 `[Console]::OutputEncoding`

### 錯誤處理：
- Try-Catch 包裹所有關鍵操作
- 詳細的錯誤日誌
- 回滾機制（如適用）

### 日誌記錄：
- 多級別日誌（INFO, WARNING, ERROR, CRITICAL）
- 時間戳記
- 操作記錄
- 結果記錄

### 使用者體驗：
- 清晰的進度顯示
- 繁體中文介面
- 交互式確認（重要操作）
- 詳細的報告生成

---

## 四、測試計劃

### 測試環境：
- Windows 10 1507 - 22H2
- Windows 11 21H2 - 24H2
- 安全模式（F8）
- 正常模式

### 測試項目：
1. 所有模塊功能測試
2. UTF-8 編碼測試
3. 錯誤處理測試
4. 回滾機制測試
5. 效能測試
6. 相容性測試

---

## 五、發布計劃

### GitHub 倉庫結構：
```
SafeModeDefender/
├── README.md                     # 專案說明（中英文）
├── LICENSE                       # MIT License
├── CHANGELOG.md                  # 更新日誌
├── CONTRIBUTING.md               # 貢獻指南
├── docs/                         # 完整文檔
├── src/                          # 原始碼
├── releases/                     # 發布版本
└── tests/                        # 測試腳本
```

### 文檔要求：
- 完整的 README（中英文）
- 詳細的使用手冊
- 技術文檔
- FAQ
- 貢獻指南

---

**設計完成，準備進入並行開發階段。**
