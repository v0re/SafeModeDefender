# SafeModeDefender 外部工具整合計畫

## 概述

本文檔列出了經過篩選的優質開源安全工具，這些工具將被整合到 SafeModeDefender 中，並提供統一的中文化雙模式介面（GUI 交互式選單 + CLI 命令列）。

## 工具篩選標準

1. **GitHub 星級** > 500（成熟度指標）
2. **支援 Windows 平台**
3. **優先支援安全模式運行**
4. **提供 CLI 或可自動化執行**
5. **活躍維護**（近期有更新）
6. **開源授權**（MIT、GPL 等）

## 精選工具清單（按類別）

### 類別 A：惡意軟體檢測與移除

| 工具名稱 | GitHub URL | 星級 | 安全模式 | 核心功能 |
|---------|-----------|------|---------|---------|
| **ClamAV** | https://github.com/Cisco-Talos/clamav | 6,256 | ✓ | 開源跨平台防毒引擎，檢測木馬、病毒、惡意軟體 |
| **Chainsaw** | https://github.com/WithSecureLabs/chainsaw | 3,443 | ✓ | Windows 事件日誌鑑識工具，支援 Sigma 規則 |
| **Harden-Windows-Security** | https://github.com/HotCakeX/Harden-Windows-Security | 4,136 | ✓ | PowerShell 安全強化腳本，多級別防護 |

### 類別 B：註冊表清理與修復

| 工具名稱 | GitHub URL | 星級 | 安全模式 | 核心功能 |
|---------|-----------|------|---------|---------|
| **WinUtil** | https://github.com/ChrisTitusTech/winutil | 47,598 | ✓ | 全能 Windows 工具，系統優化、修復、調整 |
| **Optimizer** | https://github.com/hellzerg/optimizer | 18,028 | ✓ | 隱私和安全增強工具，修復註冊表問題 |

### 類別 C：磁碟分區恢復與資料救援

| 工具名稱 | GitHub URL | 星級 | 安全模式 | 核心功能 |
|---------|-----------|------|---------|---------|
| **TestDisk** | https://github.com/cgsecurity/testdisk | 2,300 | ✓ | 磁碟分區恢復、引導扇區修復 |
| **PhotoRec** | https://github.com/cgsecurity/testdisk | 2,300 | ✓ | 檔案資料恢復（480+ 檔案格式） |
| **Digler** | https://github.com/ostafen/digler | 1,100 | ? | 取證磁碟分析和檔案恢復 |

### 類別 D：網路診斷與修復

| 工具名稱 | GitHub URL | 星級 | 安全模式 | 核心功能 |
|---------|-----------|------|---------|---------|
| **NETworkManager** | https://github.com/BornToBeRoot/NETworkManager | 8,000 | ✗ | 網路管理和故障排除統一介面 |
| **Sniffnet** | https://github.com/GyulyVGC/sniffnet | 32,800 | ✗ | 跨平台網路流量監控 |

### 類別 E：系統完整性檢查

| 工具名稱 | GitHub URL | 星級 | 安全模式 | 核心功能 |
|---------|-----------|------|---------|---------|
| **WinUtil** | https://github.com/ChrisTitusTech/winutil | 47,600 | ✓ | 整合 SFC 和 DISM 功能 |
| **Windows-Maintenance-Tool** | https://github.com/ios12checker/Windows-Maintenance-Tool | 1,100 | ✓ | Batch + PowerShell 維護工具包 |

### 類別 F：隱私保護與遙測禁用

| 工具名稱 | GitHub URL | 星級 | 安全模式 | 核心功能 |
|---------|-----------|------|---------|---------|
| **privacy.sexy** | https://github.com/undergroundwires/privacy.sexy | 5,400 | ? | 隱私和安全最佳實踐腳本生成器 |
| **WindowsSpyBlocker** | https://github.com/crazy-max/WindowsSpyBlocker | 5,100 | ? | 阻止 Windows 間諜活動和跟踪 |

### 類別 G：防火牆與端口管理

| 工具名稱 | GitHub URL | 星級 | 安全模式 | 核心功能 |
|---------|-----------|------|---------|---------|
| **simplewall** | https://github.com/henrypp/simplewall | 8,000 | ✓ | Windows 過濾平台 (WFP) 管理工具 |
| **WindowsFirewallRuleset** | https://github.com/metablaster/WindowsFirewallRuleset | 177 | ✓ | PowerShell 防火牆規則自動化配置 |

### 類別 H：權限提升檢測

| 工具名稱 | GitHub URL | 星級 | 安全模式 | 核心功能 |
|---------|-----------|------|---------|---------|
| **PrivescCheck** | https://github.com/itm4n/PrivescCheck | 3,700 | ? | PowerShell 權限提升漏洞檢測 |
| **windows-privesc-check** | https://github.com/pentestmonkey/windows-privesc-check | 1,500 | ? | 獨立可執行文件，檢查提權向量 |
| **Windows-Exploit-Suggester** | https://github.com/AonCyberLabs/Windows-Exploit-Suggester | 2,900 | ? | Python 腳本，比對系統補丁與漏洞 |

### 類別 I：記憶體分析與漏洞檢測

| 工具名稱 | GitHub URL | 星級 | 安全模式 | 核心功能 |
|---------|-----------|------|---------|---------|
| **Volatility Framework** | https://github.com/volatilityfoundation/volatility | 8,000 | ✗ | 開源記憶體取證框架 |
| **CVE Binary Tool** | https://github.com/ossf/cve-bin-tool | 1,600 | ✓ | 掃描軟體中的已知漏洞 |
| **MemProcFS-Analyzer** | https://github.com/LETHAL-FORENSICS/MemProcFS-Analyzer | 694 | ? | PowerShell 記憶體轉儲分析 |

### 類別 J：系統優化與垃圾清理

| 工具名稱 | GitHub URL | 星級 | 安全模式 | 核心功能 |
|---------|-----------|------|---------|---------|
| **WinUtil** | https://github.com/ChrisTitusTech/winutil | 47,600 | ✓ | 系統優化、調整、修復 |
| **AtlasOS** | https://github.com/Atlas-OS/Atlas | 19,800 | ? | 透過 Playbooks 優化 Windows 效能和隱私 |
| **BleachBit** | https://github.com/bleachbit/bleachbit | 4,400 | ? | 系統清理工具，釋放磁碟空間 |

## 優先整合工具（第一階段）

基於安全模式支援、星級和功能覆蓋，以下工具將優先整合：

### 🔥 高優先級（必須整合）

1. **WinUtil** (47,600 ⭐) - 全能工具，涵蓋多個類別
2. **Optimizer** (18,028 ⭐) - 隱私和安全增強
3. **TestDisk + PhotoRec** (2,300 ⭐) - 磁碟修復和資料恢復
4. **simplewall** (8,000 ⭐) - 防火牆管理
5. **ClamAV** (6,256 ⭐) - 防毒掃描
6. **Chainsaw** (3,443 ⭐) - 事件日誌分析
7. **PrivescCheck** (3,700 ⭐) - 權限提升檢測

### ⚡ 中優先級（建議整合）

8. **Harden-Windows-Security** (4,136 ⭐) - 安全強化
9. **privacy.sexy** (5,400 ⭐) - 隱私腳本生成
10. **WindowsSpyBlocker** (5,100 ⭐) - 遙測阻止
11. **NETworkManager** (8,000 ⭐) - 網路診斷
12. **BleachBit** (4,400 ⭐) - 系統清理

### 💡 低優先級（可選整合）

13. **AtlasOS** (19,800 ⭐) - 系統優化（但可能過於激進）
14. **Volatility** (8,000 ⭐) - 記憶體分析（進階用戶）
15. **CVE Binary Tool** (1,600 ⭐) - 漏洞掃描

## 整合方式

### 1. 自動下載與安裝

- 工具首次使用時自動從 GitHub Releases 下載
- 儲存到 `SafeModeDefender\Tools\{tool_name}\` 目錄
- 驗證檔案完整性（SHA256）

### 2. 中文化封裝

每個工具提供：
- **中文選單介面**：翻譯所有選項和說明
- **預設配置**：針對 APT 攻擊場景優化參數
- **執行前提示**：說明工具功能和風險
- **執行後報告**：整合結果到 SafeModeDefender 報告系統

### 3. 雙模式支援

**GUI 模式（交互式選單）**：
```
╔══════════════════════════════════════════════════════════════════════════╗
║                      外部工具：TestDisk                                  ║
╚══════════════════════════════════════════════════════════════════════════╝

  [1] 恢復丟失的分區
  [2] 修復引導扇區
  [3] 恢復已刪除的檔案 (PhotoRec)
  [4] 進階模式（直接啟動 TestDisk）
  [B] 返回
```

**CLI 模式（命令列）**：
```bash
# 使用外部工具
SafeModeDefender.bat --cli --tool testdisk --action recover

# 靜默模式自動執行
SafeModeDefender.bat --cli --tool optimizer --action privacy --silent --autofix
```

### 4. 配置檔批次執行

支援 JSON 配置檔，一次執行多個工具：

```json
{
  "tasks": [
    {
      "tool": "clamav",
      "action": "scan",
      "target": "C:\\",
      "autofix": false
    },
    {
      "tool": "optimizer",
      "action": "privacy",
      "autofix": true
    },
    {
      "tool": "privesccheck",
      "action": "audit",
      "report": true
    }
  ]
}
```

執行：
```bash
SafeModeDefender.bat --cli --config security_audit.json
```

## 技術實現

### 目錄結構

```
SafeModeDefender_v2/
├── SafeModeDefender.bat          # 主啟動器（已更新支援 CLI）
├── Core/
│   ├── CLI_Handler.ps1           # 命令列參數處理
│   ├── External_Tools_Manager.ps1 # 外部工具管理器
│   └── Tool_Wrappers/            # 各工具的中文化封裝腳本
│       ├── WinUtil_Wrapper.ps1
│       ├── Optimizer_Wrapper.ps1
│       ├── TestDisk_Wrapper.ps1
│       ├── ClamAV_Wrapper.ps1
│       └── ...
├── Tools/                        # 外部工具安裝目錄（自動下載）
│   ├── winutil/
│   ├── optimizer/
│   ├── testdisk/
│   └── ...
└── Configs/                      # 配置檔範例
    ├── full_security_scan.json
    ├── privacy_hardening.json
    └── malware_removal.json
```

### 工具封裝腳本範例

每個工具的 Wrapper 腳本應包含：

1. **下載函數**：`Download-Tool`
2. **安裝函數**：`Install-Tool`
3. **驗證函數**：`Verify-Tool`
4. **執行函數**：`Invoke-Tool`
5. **中文選單**：`Show-Menu`
6. **結果解析**：`Parse-Result`

## 授權與致謝

所有整合的外部工具均保留其原始授權和版權聲明。SafeModeDefender 僅提供統一的介面和自動化封裝，不修改工具本身的程式碼。

每個工具在使用時都會顯示：
- 工具名稱和版本
- GitHub 儲存庫 URL
- 原始作者和授權資訊
- 鼓勵使用者給原專案 Star

## 下一步行動

1. ✅ 完成工具搜尋和評估
2. 🔄 開發工具整合框架
3. 🔄 創建高優先級工具的封裝腳本
4. ⏳ 測試所有工具在安全模式下的運行
5. ⏳ 撰寫完整的使用文檔
6. ⏳ 更新 GitHub 儲存庫

---

**更新日期**：2026-02-19  
**版本**：v2.1 (External Tools Integration)
