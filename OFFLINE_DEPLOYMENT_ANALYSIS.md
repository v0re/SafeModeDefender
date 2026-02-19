# SafeModeDefender 工具離線運作能力分析

**文檔版本**：1.0  
**分析日期**：2026-02-19  
**目的**：確保所有整合工具在無網路環境（安全模式）下能正常運作

---

## 背景

Windows 安全模式通常在以下情況下沒有網路連線：
1. **安全模式（不含網路功能）**：最常用的模式，完全沒有網路驅動
2. **惡意軟體阻斷網路**：部分 APT 攻擊會禁用網路介面卡
3. **隔離環境**：企業環境中的隔離主機

因此，**所有工具必須能在完全離線的環境下運作**。

---

## 已整合工具離線能力分析

### 1. WinUtil (Chris Titus Tech's Windows Utility)

**GitHub**：https://github.com/ChrisTitusTech/winutil  
**星級**：47,600+

#### 離線需求分析

**問題**：
- WinUtil 是一個 **PowerShell 腳本**，通常透過 `irm christitus.com/win | iex` 從網路下載執行
- 腳本本身會從 GitHub 下載額外的資源和配置檔
- 部分功能需要從網路下載軟體包（如 Chocolatey, Winget）

**離線解決方案**：
1. **預先下載完整腳本**：
   - 下載 `winutil.ps1` 主腳本（約 50KB）
   - 下載所有相依的 JSON 配置檔
   
2. **修改腳本以支援離線模式**：
   - 檢測網路狀態
   - 禁用需要網路的功能（軟體安裝）
   - 保留離線可用的功能（系統調整、服務管理、註冊表修改）

3. **打包策略**：
   ```
   Tools/WinUtil/
   ├── winutil.ps1           # 主腳本
   ├── config/               # 配置檔目錄
   │   ├── applications.json
   │   ├── tweaks.json
   │   └── feature.json
   └── README.txt            # 離線使用說明
   ```

**離線可用功能**：
- ✅ 系統調整（Tweaks）
- ✅ 服務管理
- ✅ 註冊表修改
- ✅ 隱私設定
- ❌ 軟體安裝（需要網路）
- ❌ Windows 更新（需要網路）

**結論**：**部分離線可用**，需要預先下載腳本和配置檔

---

### 2. Optimizer

**GitHub**：https://github.com/hellzerg/optimizer  
**星級**：18,000+

#### 離線需求分析

**問題**：
- Optimizer 是一個 **獨立的 .exe 執行檔**
- 不依賴外部資源或網路連線
- 所有功能都內建在執行檔中

**離線解決方案**：
1. **直接下載執行檔**：
   - 下載 `Optimizer-18.7.exe`（約 2MB）
   - 無需額外配置

2. **打包策略**：
   ```
   Tools/Optimizer/
   ├── Optimizer.exe         # 主執行檔
   └── README.txt            # 使用說明
   ```

**離線可用功能**：
- ✅ 所有功能完全離線可用
- ✅ 隱私設定
- ✅ 系統優化
- ✅ 服務禁用
- ✅ 註冊表清理

**結論**：**完全離線可用**，無需任何網路連線

---

### 3. TestDisk & PhotoRec

**GitHub**：https://github.com/cgsecurity/testdisk  
**星級**：2,300+

#### 離線需求分析

**問題**：
- TestDisk 是一個 **獨立的命令列工具**
- 不依賴外部資源或網路連線
- 所有功能都內建在執行檔中

**離線解決方案**：
1. **下載完整的 ZIP 包**：
   - 下載 `testdisk-7.2-WIP.win.zip`（約 5MB）
   - 解壓縮後包含所有必要的執行檔

2. **打包策略**：
   ```
   Tools/TestDisk/
   ├── testdisk_win.exe      # 磁碟修復工具
   ├── photorec_win.exe      # 檔案恢復工具
   ├── fidentify_win.exe     # 檔案識別工具
   └── README.txt            # 使用說明
   ```

**離線可用功能**：
- ✅ 所有功能完全離線可用
- ✅ 分區恢復
- ✅ 引導扇區修復
- ✅ 檔案恢復
- ✅ 磁碟分析

**結論**：**完全離線可用**，無需任何網路連線

---

### 4. ClamAV

**GitHub**：https://github.com/Cisco-Talos/clamav  
**星級**：6,200+

#### 離線需求分析

**問題**：
- ClamAV 是一個 **防毒引擎**
- **必須依賴病毒特徵碼資料庫**才能運作
- 預設使用 `freshclam` 從網路更新資料庫
- 沒有特徵碼資料庫，ClamAV 完全無法檢測病毒

**病毒資料庫結構**：
- `main.cvd` - 主要病毒特徵碼（約 160MB）
- `daily.cvd` - 每日更新特徵碼（約 80MB）
- `bytecode.cvd` - 字節碼特徵碼（約 300KB）

**離線解決方案**：

1. **預先下載病毒資料庫**：
   ```bash
   # 從官方鏡像下載
   wget http://database.clamav.net/main.cvd
   wget http://database.clamav.net/daily.cvd
   wget http://database.clamav.net/bytecode.cvd
   ```

2. **打包策略**：
   ```
   Tools/ClamAV/
   ├── bin/
   │   ├── clamscan.exe      # 掃描工具
   │   ├── freshclam.exe     # 更新工具（離線環境不可用）
   │   └── sigtool.exe       # 特徵碼工具
   ├── database/             # 病毒資料庫目錄
   │   ├── main.cvd          # 主要特徵碼（160MB）
   │   ├── daily.cvd         # 每日特徵碼（80MB）
   │   └── bytecode.cvd      # 字節碼特徵碼（300KB）
   ├── conf/
   │   └── clamd.conf        # 配置檔
   └── README.txt            # 離線使用說明
   ```

3. **配置檔修改**：
   ```ini
   # clamd.conf
   DatabaseDirectory C:\SafeModeDefender\Tools\ClamAV\database
   ```

4. **資料庫更新策略**：
   - **線上環境**：使用者可以手動執行 `freshclam` 更新資料庫
   - **離線環境**：使用預先打包的資料庫
   - **定期發布**：每月發布一次包含最新資料庫的 SafeModeDefender 版本

**離線可用功能**：
- ✅ 病毒掃描（使用預先下載的資料庫）
- ✅ 檔案分析
- ✅ 隔離區管理
- ❌ 資料庫更新（需要網路）

**資料庫時效性問題**：
- 病毒資料庫每天更新 1-2 次
- 離線環境下，資料庫會逐漸過時
- **建議**：在有網路的環境下先更新資料庫，再進入安全模式

**結論**：**可離線運作**，但需要預先打包病毒資料庫（約 240MB）

---

### 5. simplewall

**GitHub**：https://github.com/henrypp/simplewall  
**星級**：8,000+

#### 離線需求分析

**問題**：
- simplewall 是一個 **獨立的 .exe 執行檔**
- 不依賴外部資源或網路連線
- 但會從 GitHub 下載規則更新

**離線解決方案**：
1. **下載執行檔和預設規則**：
   - 下載 `simplewall.exe`（約 2MB）
   - 下載 `blocklist.xml`（規則檔案）

2. **打包策略**：
   ```
   Tools/simplewall/
   ├── simplewall.exe        # 主執行檔
   ├── profile.xml           # 配置檔
   ├── blocklist.xml         # 預設規則
   └── README.txt            # 使用說明
   ```

**離線可用功能**：
- ✅ 防火牆規則管理
- ✅ 應用程式阻擋
- ✅ 網路監控
- ❌ 規則更新（需要網路）

**結論**：**完全離線可用**，規則更新為可選功能

---

### 6. PrivescCheck

**GitHub**：https://github.com/itm4n/PrivescCheck  
**星級**：3,700+

#### 離線需求分析

**問題**：
- PrivescCheck 是一個 **PowerShell 腳本**
- 不依賴外部資源或網路連線
- 所有檢測邏輯都在腳本中

**離線解決方案**：
1. **下載 PowerShell 腳本**：
   - 下載 `PrivescCheck.ps1`（約 200KB）

2. **打包策略**：
   ```
   Tools/PrivescCheck/
   ├── PrivescCheck.ps1      # 主腳本
   └── README.txt            # 使用說明
   ```

**離線可用功能**：
- ✅ 所有功能完全離線可用
- ✅ 權限提升漏洞檢測
- ✅ 系統配置審計
- ✅ 服務權限檢查

**結論**：**完全離線可用**，無需任何網路連線

---

## 離線部署策略總結

### 完全離線可用（無需網路）

| 工具 | 檔案大小 | 備註 |
|------|---------|------|
| **Optimizer** | ~2 MB | 獨立執行檔，無依賴 |
| **TestDisk** | ~5 MB | 獨立工具，無依賴 |
| **simplewall** | ~2 MB | 獨立執行檔，規則更新為可選 |
| **PrivescCheck** | ~200 KB | PowerShell 腳本，無依賴 |

### 部分離線可用（需要預先下載）

| 工具 | 檔案大小 | 離線限制 |
|------|---------|---------|
| **WinUtil** | ~50 KB + 配置檔 | 軟體安裝功能不可用 |
| **ClamAV** | ~10 MB (執行檔) + 240 MB (資料庫) | 資料庫更新不可用，會逐漸過時 |

### 總計檔案大小

- **基本工具包**（不含 ClamAV）：~10 MB
- **完整工具包**（含 ClamAV 資料庫）：~250 MB

---

## 離線部署架構設計

### 方案一：完整打包（推薦）

**優點**：
- 開箱即用，無需網路
- 適合完全離線環境
- 包含最新的病毒資料庫

**缺點**：
- 檔案體積較大（~250 MB）
- 病毒資料庫會逐漸過時

**適用場景**：
- 企業隔離環境
- 無網路的安全模式
- 緊急修復場景

### 方案二：按需下載

**優點**：
- 核心工具包體積小（~10 MB）
- 病毒資料庫永遠是最新的

**缺點**：
- 需要網路連線
- 首次使用需要下載

**適用場景**：
- 含網路功能的安全模式
- 有網路的正常環境

### 方案三：混合模式（最佳方案）

**策略**：
1. **核心版本**（~10 MB）：
   - 包含所有完全離線可用的工具
   - Optimizer, TestDisk, simplewall, PrivescCheck
   - 適合快速部署

2. **完整版本**（~250 MB）：
   - 包含所有工具 + ClamAV 病毒資料庫
   - 適合離線環境

3. **線上更新**：
   - 提供 `Update-OfflineResources.ps1` 腳本
   - 在有網路時更新 ClamAV 資料庫和 WinUtil 配置

---

## 實施計畫

### 階段一：建立離線資源管理器

創建 `Offline_Resources_Manager.ps1`：
- 檢測網路狀態
- 管理離線資源
- 提供更新機制

### 階段二：修改所有 Wrapper

更新所有 Wrapper 腳本以支援離線模式：
- 檢測資源是否存在
- 提供離線/線上雙模式
- 顯示資源狀態和時效性

### 階段三：創建資源打包腳本

創建 `Build-OfflinePackage.ps1`：
- 自動下載所有離線資源
- 打包成兩個版本（核心版 + 完整版）
- 生成 SHA256 校驗碼

### 階段四：更新文檔

更新所有文檔以說明離線部署：
- README.md
- 每個工具的使用說明
- 離線部署指南

---

## 建議

1. **預設使用完整版本**：
   - 在 GitHub Releases 提供完整版本（含 ClamAV 資料庫）
   - 確保使用者在離線環境下能正常使用

2. **每月更新一次**：
   - 定期發布包含最新病毒資料庫的版本
   - 在 Release Notes 中標註資料庫日期

3. **提供線上更新腳本**：
   - 讓使用者在有網路時更新資源
   - 自動檢測資源時效性

4. **明確標示離線限制**：
   - 在文檔中清楚說明哪些功能需要網路
   - 提供離線替代方案

---

## 結論

SafeModeDefender 的所有工具都可以在離線環境下運作，但需要：

1. **預先下載 ClamAV 病毒資料庫**（240 MB）
2. **預先下載 WinUtil 腳本和配置檔**（50 KB）
3. **其他工具完全離線可用**

建議採用**混合模式**，提供核心版和完整版兩個版本，滿足不同使用者的需求。
