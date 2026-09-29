# V0.1.1 驗證紀錄

更新日期：2026-09-28

## V0.1.1 自動與版面驗證

- 對外版本 V0.1.1；內部建置號 9；首頁顯示 `V0.1.1(20260928)`。
- iOS Simulator generic build 與 Xcode Static Analyzer 成功。
- iPhone 17 Pro 模擬器 14/14 項單元測試通過。
- iPhone 16 與 iPhone 17 Pro 模擬器安裝及啟動成功；兩種首頁尺寸均無版本文字截斷。
- 設定頁回饋按鈕已依 TGoshake 統一為同列 `LabeledContent`：左側 `使用回饋信箱`、右側 `atexapp.lin@gmail.com`；VoiceOver 標籤及郵件／複製行為維持不變。
- 驗證時 Mac 畫面處於鎖定狀態，無法以 UI 自動化開啟設定頁，因此兩種尺寸的設定頁截圖、超大動態文字與實際點擊郵件分支尚未完成。
- iPhoneOS 開發簽署建置成功；Info.plist 確認版本 0.1.1、build 9、Bundle ID 維持不變。
- 使用相同 Bundle ID 覆蓋安裝至實體 iPhone 16 成功，未執行解除安裝；裝置版本讀回、啟動及程序存活確認均成功。

## V0.1.0 自動、版面與實機驗證

- 對外版本 V0.1.0；內部建置號 8；首頁顯示 `V0.1.0(20260925)`。
- iOS Simulator generic build 與 Xcode Static Analyzer 成功。
- iPhone 17 Pro 模擬器 14/14 項單元測試通過。
- 實體 iPhone 16 14/14 項單元測試通過。
- iPhone 16 與 iPhone 17 Pro 模擬器首頁版面均無版本文字截斷或主要操作遮蔽。
- iPhone 16 模擬器設定頁顯示 `Atex Lin` 與 `atexapp.lin@gmail.com`，文字完整且回饋列具明確 VoiceOver 標籤。
- iPhoneOS 開發簽署建置成功；Info.plist 確認版本 0.1.0、build 8、Bundle ID 維持不變。
- 使用相同 Bundle ID 覆蓋安裝至實體 iPhone 16 成功，未執行解除安裝；啟動成功且程序持續運行。
- 郵件 App 的實際開啟或無郵件 App 時複製信箱的分支，仍需依實機郵件設定人工確認。

## V0.1.0 交付驗證

- Google Drive：已同步至 `12.Codex/SeeZMemo/V0.1.0/SeeZMemo_V0.1.0_Source`；checksum dry-run 無差異，抽樣 SHA-256 讀回一致。
- GitHub：已推送至 `atex923/SeeZMemo` 的 `main`，並以遠端 ref 讀回確認。
- iPhone 16：已使用相同 Bundle ID 覆蓋安裝並成功啟動，未解除安裝 App。
- 交付內容排除 `.git`、`.DS_Store`、DerivedData、Xcode 個人狀態及 Python 快取；本次未建立一般更新用 ZIP。

## V0.0.7 自動與實機驗證

- 對外版本 V0.0.7；內部建置號 7。
- iOS Simulator generic build 成功（未簽章）。
- iPhone 17 Pro 模擬器 13/13 項單元測試通過。
- 實體 iPhone 16 13/13 項單元測試通過；其中以帶有 EXIF GPS 的實際 JPEG 資料驗證 ImageIO 座標解析成功。
- GPS 在照片重新編碼後仍由 `PlacePhoto` 獨立保存，並會隨備份／同步資料保存與還原。
- 修正位置地址欄可捲動避開鍵盤，並保留鍵盤最右側隱藏按鈕。
- 地址右側新增 44×44 點按區域的放大鏡；完整地址搜尋失敗時改取目前位置周圍最近結果，並以紅色座標提示為鄰近點位。
- 修正位置頁面的「用 Google Maps 開啟」已移除。
- iPhoneOS 簽署建置、相同 Bundle ID 覆蓋安裝及遠端啟動均成功，未解除安裝或清除資料容器。
- 實機自動測試不等同於操作真實相簿選取器；相簿權限與使用者指定原始照片仍需在手機畫面人工確認。

## V0.0.5 自動驗證

- 對外版本 V0.0.5；內部建置號 5。
- iOS Simulator generic build 成功（未簽章）。
- iPhone 17 Pro 模擬器 12/12 項單元測試通過。
- 新增測試以實際 JPEG EXIF GPS metadata 驗證座標讀取。
- 相簿匯入要求保留目前編碼，以提高 GPS metadata 可取得性；沒有 GPS 的照片仍可加入。
- 首頁拍照完成後建立草稿並留在首頁，使用者可稍後由草稿區補填紀錄。
- 尚未驗證實體 iPhone 相簿提供的原始 metadata、相簿權限與現場照片 GPS。

## V0.0.4 自動驗證

- 對外版本 V0.0.4；內部建置號 4。
- iOS Simulator generic build 成功（未簽章）。
- iPhone 17 Pro（iOS 26.3）模擬器 11/11 項單元測試通過。
- 同一模擬器安裝並啟動 `com.atex1.SeeZMemo` 成功。
- 新增測試涵蓋 0 筆店家仍可建立有效首次同步 envelope，以及照片 UUID／首張順序可保存。
- 尚未驗證實體 iPhone 安裝、相機／相簿／定位權限，或真實 iCloud Drive／Google Drive 寫入與跨裝置往返。

## 已完成

- Xcode 26.6／iOS 26.5 SDK Debug 模擬器建置成功。
- Xcode Static Analyzer 成功。
- iPhone 16 模擬器 9/9 項自動測試通過。
- iPhone 17 Pro 模擬器 9/9 項自動測試通過。
- 測試涵蓋：
  - 每筆照片上限 10 張。
  - 地圖範圍選項及預設 2 公里。
  - 店家座標直線距離計算。
  - 類型記憶的前三名使用率與第四個最新類型。
  - 設為首張後的照片排序。
  - 喵仔流水帳固定文字格式。
  - 分享 JPEG 長邊不超過 2048 像素且低於 500 KB。
  - Vision 英文招牌 OCR。
- iPhone 16 模擬器實際覆蓋安裝及 App 啟動成功，既有資料庫可開啟。
- 實際首頁截圖為 1179×2556，已確認無程式標題、紅色玻璃相機圖示、清單／新增入口、草稿收合、地圖及版本編譯日期。
- Development Team `Y3ZLRY9835` 實機簽章建置成功。
- Bundle ID：`com.atex1.SeeZMemo`。
- 對外版本：V0.0.3；內部建置號：3。
- 最終 V0.0.3 已覆蓋安裝至 `Atex-iPhone16`，沿用 Bundle ID 以保留既有資料。
- 最終 V0.0.3 已由命令列成功啟動，iOS 回報 Bundle ID `com.atex1.SeeZMemo` 啟動完成。
- `Info.plist`、Xcode 專案與 asset catalog 均可建置。
- iPhone 16 共 13 張操作 PNG，尺寸 1179×2556。
- iPhone 17 Pro 共 13 張操作 PNG，尺寸 1206×2622。
- 操作預覽頁載入 26 張裝置頁面圖；另有兩張總覽圖與實際模擬器首頁截圖。

## 實機互動邊界

自動化測試可驗證資料、壓縮、排序與 OCR 核心規則，但以下仍需在解鎖實機上人工操作：

- 真實相機、照片寫入相簿及定位權限。
- 繁中、日文、韓文與自然場景 OCR 準確度。
- Facebook 接收多張照片及預填文字的當前版本行為；App 已將文字同步複製到剪貼簿作為備援。
- Google Maps App 與網頁版兩種外開路線。

最終版安裝成功；首次命令列遠端啟動因手機自動鎖定被 iOS 拒絕，解鎖後重試已成功啟動。
