# SafeModeDefender v2.0 - Windows 安全模式深度清理工具

**SafeModeDefender** 是一個基於真實世界威脅情報開發的專業級 Windows 安全模式深度清理工具套件。它旨在幫助使用者應對高級持續性威脅 (APT)，並提供全面的系統安全檢測與修復功能。

**威脅情報來源：** Exploit-DB, Shodan, CVE Database, CISA KEV, 實際攻擊案例分析

**授權：** MIT License

**GitHub：** https://github.com/v0re/SafeModeDefender

---

## 核心功能

- **全面掃描**: 針對 33 個專業級安全模塊進行深度掃描，涵蓋網路、權限、註冊表、檔案系統、記憶體、隱私權、系統完整性、環境變數和防火牆等各個層面。
- **交互式優化**: 提供交互式的防火牆和服務優化功能，根據使用者的實際需求進行精細化配置。
- **自動修復**: 提供可選的自動修復功能，快速解決已知的安全問題。
- **詳細報告**: 生成 HTML 和 CSV 格式的掃描報告，詳細列出所有發現的問題和修復建議。
- **安全模式優先**: 專為在 Windows 安全模式下運行而設計，以獲得最佳的清理效果。
- **備用方案**: 考慮到 PowerShell 可能不可用的情況，提供了批次檔備用方案。

---

## 如何使用

1. **下載工具包**: 下載 `SafeModeDefender_v2.zip` 並解壓縮到您的電腦上。
2. **進入安全模式**: 
   - 按住 `Shift` 鍵並點擊「重新啟動」。
   - 選擇「疑難排解」→「進階選項」→「啟動設定」。
   - 按 `F4` 進入安全模式，或按 `F5` 進入含網路功能的安全模式。
3. **運行主啟動器**: 
   - 在安全模式下，右鍵點擊 `SafeModeDefender.bat` 並選擇「以系統管理員身份執行」。
4. **遵循選單指示**: 
   - 根據主選單的提示，選擇您需要的功能（例如，執行完整掃描、單獨掃描某個類別、查看報告等）。
5. **查看報告**: 
   - 掃描完成後，報告將生成在 `Reports` 目錄下。請仔細查看報告內容，並根據建議進行手動修復（如果需要）。

---

## 模塊詳情

### 類別 A：網路服務與端口安全
- **A1_SMB_Security**: SMB 服務安全強化
- **A2_RDP_Security**: RDP 服務安全強化
- **A3_UPnP_Disable**: UPnP/SSDP 服務禁用
- **A4_mDNS_Disable**: mDNS/Bonjour 服務禁用
- **A5_WinRM_Security**: WinRM/PowerShell Remoting 安全
- **A6_LLMNR_Disable**: LLMNR/NetBIOS-NS 禁用
- **A7_Port_Scanner**: 危險端口全面掃描與封鎖

### 類別 B：系統權限與提權防護
- **B1_UAC_Hardening**: UAC 安全強化
- **B2_SYSTEM_Audit**: SYSTEM 權限濫用審計
- **B3_Token_Protection**: Token 竊取防護
- **B4_Service_Security**: 服務權限與 DLL 劫持防護
- **B5_ScheduledTask_Audit**: 可疑排程任務審計

### ... (其他類別和模塊)

---

## 注意事項

- **務必在安全模式下以系統管理員權限運行此工具。**
- **在運行前，請務必備份您的重要資料。**
- 此工具僅為輔助性質，無法保證 100% 清除所有惡意軟體。如果您的系統遭受嚴重感染，建議尋求專業資安團隊的協助。

---

## 貢獻

歡迎您為此項目做出貢獻！您可以：
- 在 GitHub 上提交問題或建議
- Fork 此項目並提交 Pull Request
- 分享給需要的朋友

讓我們一起讓網路世界更安全！🛡️
