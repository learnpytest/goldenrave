# Golden Retriever Menu Bar Companion — 設計規格

## 狀態

設計草案，等待使用者審閱。

## 1. 產品目標

建立一個只支援 macOS 的原生選單列工具，提供 Timex 類似的自動使用時間追蹤與休息提醒，但以一隻「約兩個月大的真實幼黃金獵犬」作為主要互動角色。

產品的核心不是把狗做成裝飾，而是讓狗的動作直接傳達電腦使用狀態：走路、跑步、玩球、跳躍與趴下休息都要有不同意義。

第一版的成功條件：

- 使用者不打開主視窗，也能從選單列知道目前連續使用多久。
- 預設模式不記錄 App 名稱、視窗標題或瀏覽器網址。
- 使用者主動開啟完整模式後，才可查看更細的使用時間分布。
- 休息提醒明顯但不強制鎖住電腦。
- 所有動畫都維持同一隻兩個月大的幼黃金外型，不得退回 emoji、幾何 SVG 或泛用卡通狗。

## 2. 平台與技術選擇

- 平台：macOS 14 Sonoma 以上。
- UI：SwiftUI。
- 選單列整合：SwiftUI `MenuBarExtra`，必要時以 AppKit `NSStatusItem` 補足系統行為。
- 背景活動監控：Swift 原生 activity／idle-time API。
- 詳細使用追蹤：AppKit／Accessibility API，僅在使用者開啟完整模式後啟用。
- 本機資料：SQLite，資料檔留在使用者的 Application Support 目錄。
- 動畫：同一個幼黃金角色的逐格動畫資產；由 `DogAnimationPlayer` 根據狀態播放對應 frame loop。

選擇原生 Swift／SwiftUI＋AppKit，是為了讓常駐選單列工具維持低資源使用、正確處理 macOS 權限與通知，也避免 Electron 類 runtime 成為監控工具本身的負擔。

## 3. 系統架構

```text
Activity Source
      ↓
Activity Engine ─────────→ Local Store
      ↓                         ↓
Dog State Machine          Statistics View
      ↓
Dog Animation Player
      ↓
Menu Bar Shell / Popover / Break Reminder
```

### 3.1 MenuBarShell

負責選單列上的小黃金動畫與連續使用時間文字，例如「幼黃金＋42m」。點擊後開啟 Popover，不建立常駐 Dock 視窗。

### 3.2 ActivityEngine

把鍵盤／滑鼠活動與閒置時間整理成可測試的 activity stream，產生：

- 目前是否正在使用電腦
- 目前連續使用時間
- 今日累計使用時間
- 使用者何時離開、回來或進入休息

ActivityEngine 不直接決定動畫，也不直接寫 UI；它只輸出狀態與時間資料。

### 3.3 TrackingMode

提供兩層模式：

**Private mode（預設）**

- 只記錄活動、閒置、休息與時間長度。
- 不讀取前景 App、視窗標題或瀏覽器分頁。
- 不需要將使用者的工作內容送出或同步。

**Detailed mode（主動開啟）**

- 讀取前景 App 與視窗標題。
- 對支援的瀏覽器讀取目前分頁資訊。
- 第一次開啟前顯示明確的權限用途與可記錄內容。
- 若某個瀏覽器無法取得分頁資訊，降級成 App／視窗層級，不阻斷其他功能。

兩種模式的資料都只寫入本機；v1 不提供帳號、雲端同步或遙測。

### 3.4 DogStateMachine

DogStateMachine 接收 ActivityEngine 與 BreakScheduler 的事件，輸出有限狀態：

- `idle`：沒有活動，幼黃金趴著、眨眼或輕微呼吸。
- `walk`：剛開始使用或短暫活動，小步走路、尾巴搖動。
- `run`：連續工作期間，交替換腳、耳朵與尾巴擺動。
- `play`：持續使用但尚未進入提醒區間，撲球或搖尾巴。
- `jump`：距離休息時間很近，幼黃金短暫跳起來提示。
- `rest`：使用者正在休息，幼黃金趴下並以呼吸動畫呈現倒數。

狀態轉換以事件和時間為準，不以 CPU 使用率為主要來源；這個產品是使用時間／休息工具，不是 RunCat 的 CPU meter 複製品。

## 4. 互動與提醒

### 4.1 選單列

選單列顯示：

- 真正的幼黃金逐格動畫
- 目前連續使用時間
- 休息接近時的暖橘色提示

顏色只作為輔助，不得成為唯一狀態訊號；使用者必須能靠狗的動作看懂狀態。

### 4.2 Popover

Popover 顯示：

- 今日總使用時間
- 目前連續使用時間
- 距離下一次休息的時間
- 今日已完成的休息次數
- 立即休息、延後 10 分鐘、暫停提醒
- 統計頁入口
- 隱私模式／完整模式設定入口

### 4.3 Break Reminder（強提醒但非強制）

休息時間到達前：

1. 小黃金切換成 `jump`。
2. 選單列時間文字變暖橘色。
3. 顯示通知，說明小黃金想休息。
4. 使用者點開後看到較大的休息視窗。
5. `rest` 動畫搭配休息倒數。
6. 提供「開始休息」、「延後 10 分鐘」與「跳過」；不鎖住鍵盤或螢幕。

## 5. 視覺與動畫規格

### 5.1 角色基準

以已確認的兩個月幼黃金參考圖作為 canonical reference：

- 金黃色蓬鬆長毛
- 圓而偏大的幼犬頭部
- 深色垂耳
- 短腿與圓滾身體
- 厚實胸口與奶油色胸毛
- 黑鼻子、深色眼睛、蓬鬆長尾巴

每個動作都必須是同一個角色的姿勢變化。正式資產不可由五個互不一致的生成結果拼成。

### 5.2 動畫資產

每個狀態至少提供一個完整 loop：

- `walk`：6–8 frames
- `run`：8–12 frames
- `play`：8–12 frames
- `jump`：6–8 frames
- `rest`：4–6 frames，包含胸口呼吸與眨眼

選單列尺寸會使用小尺寸版本，但保留幼黃金的辨識特徵。Popover 與休息視窗使用較大版本，讓使用者看得出動作差異。

## 6. 資料模型與本機儲存

核心資料表：

- `sessions`：開始時間、結束時間、活動秒數、追蹤模式。
- `break_events`：提醒時間、開始／延後／跳過／完成結果。
- `activity_segments`：僅在 Detailed mode 保存 App／視窗／分頁層級資料。
- `preferences`：休息間隔、延後時間、啟動設定、追蹤模式與動畫設定。

資料處理原則：

- 沒有登入帳號。
- 沒有雲端 API。
- 不保存鍵盤按鍵內容、滑鼠座標、螢幕截圖或剪貼簿。
- 提供 CSV 匯出。
- 提供清除所有資料的設定入口。

## 7. 測試與驗收

### 單元測試

- 使用假的時鐘測試 session 累計與跨午夜行為。
- 使用假的 activity source 測試 idle／active 判定。
- 測試所有 DogStateMachine 狀態轉換。
- 測試提醒的延後、跳過、完成與重新排程。
- 測試資料庫 migration 與 CSV 匯出。

### UI 測試

- 選單列顯示幼黃金與時間文字。
- Popover 顯示今日統計與操作按鈕。
- Private mode 不出現 App／視窗／網址資料。
- Detailed mode 啟用前出現權限說明。
- 休息提醒可開始、延後與跳過。

### 視覺驗收

- 五個狀態都必須是同一隻兩個月幼黃金。
- 不得出現 emoji、幾何狗或成年犬比例。
- 動作要能在選單列小尺寸下區分。
- `rest` 必須看得出趴著休息與呼吸，不只是靜態圖片。

### 效能目標

- 閒置時背景 CPU 使用量目標低於 1%。
- 動畫與監控不可持續造成明顯風扇或電池負擔。
- 選單列工具不建立不必要的 Dock 常駐視窗。

## 8. v1 不包含

- Windows 或 Linux 版本。
- 雲端同步、帳號與社交功能。
- 自動封鎖 App 或強制鎖定螢幕。
- CPU／GPU／記憶體監控。
- 醫療或姿勢診斷。
- 多種不同狗狗角色商店。

## 9. Repository 方向

程式會放在 Rachel 的個人 GitHub `rachelchen05` 帳號下。Repository 名稱在建立前再確認；本階段不建立遠端 repository、不設定 GitHub 權限，也不推送程式碼。

本機專案預計採用：

```text
GoldenRetriever/
├── GoldenRetriever.xcodeproj
├── Sources/GoldenRetriever/
├── Resources/Animation/
├── Tests/GoldenRetrieverTests/
├── Tests/GoldenRetrieverUITests/
└── docs/
```
