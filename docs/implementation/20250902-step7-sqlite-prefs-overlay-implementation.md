— 実装報告ドキュメント —
保存先: `docs/implementation/20250902-step7-sqlite-prefs-overlay-implementation.
md`
内容:

```
# Step7 実装報告（SQLite 非同期化 / Preferences / Overlay / Devメニュー）

## 目的
- UIブロックの回避（DB I/O の非同期化）
- 設定UIの提供とランタイム反映
- デバッグ可観測性の向上（取得順の明確化・ダンプ機能）

## 変更範囲（主ファイル）
- `Danmaku/Storage/ChunkStore.swift`
- `Danmaku/Preferences/DanmakuPrefs.swift`
- `Danmaku/Preferences/PreferencesView.swift`
- `Danmaku/Preferences/PreferencesWindowController.swift`
- `Danmaku/OverlayWindow.swift`
- `Danmaku/MenuBarController.swift`
- `Danmaku/AppDelegate.swift`

## 実装詳細
### 1) ChunkStore（SQLite）
- DB 位置: `~/Library/Application Support/Danmaku/danmaku.sqlite`
- PRAGMA: `journal_mode=WAL`, `synchronous=NORMAL`
- スキーマ: `chunks(id INTEGER PK, started_at REAL, ended_at REAL, text TEXT)`
- スレッド: `DispatchQueue(label: "db.chunk.store")` 上で `insert`/`latest` を実
行
- INSERT: `sqlite3_prepare_v2` → `sqlite3_bind_*` → `sqlite3_step` → `sqlite3_fi
nalize`
  - `sqlite3_bind_text(..., SQLITE_TRANSIENT)` 相当を使用（現在は `unsafeBitCast
(-1, ...)`）
- 取得（最新N件）: `ORDER BY ended_at DESC LIMIT ?` を明示
- エラーハンドリング: `prepare/step/finalize` 戻り値チェック＋`logError` で標準
出力へ
- リソース管理: `init` 失敗時は `defer { sqlite3_close(db) }`、`deinit` で `sqli
te3_close`

### 2) Preferences（設定）
- `DanmakuPrefs`: `speed`/`fontSize`/`baselineY` を `UserDefaults` で永続化
  - `registerDefaults()` によるデフォルト登録
  - 値更新時に `Notification.Name.danmakuPrefsChanged` を送出
- `PreferencesView`（SwiftUI）:
  - スライダー3種: `speed: 20..150`, `fontSize: 14..48`, `baselineY: 40..300`
  - `.onChange` で `DanmakuPrefs` に即時反映
- `PreferencesWindowController`（NSPanel）:
  - 単一インスタンス（Singleton）で呼び出し。メニュー `⌘,` から開閉

### 3) OverlayWindow（オーバーレイ）
- 透過・クリック透過・全スペース/フルスクリーン追従（`canJoinAllSpaces`, `fullSc
reenAuxiliary`）
- ウィンドウレベル: 既定 `level = .statusBar`
- `danmakuChunk` 通知でテキストを受け取り、`CATextLayer` を生成
- スクロール: 右→左、速度は `DanmakuPrefs.speed` を px/s として計算
- フォント/ベースライン: `DanmakuPrefs.fontSize`/`baselineY` を適用
- 設定変更: `danmakuPrefsChanged` で `rowOffset` をリセット（即時反映）

### 4) メニューとアプリ連携
- `MenuBarController`: Start/Stop、Preferences（`⌘,`）、Dump Latest 10（`⌘⇧D`）
- `AppDelegate`:
  - 起動時に `ChunkStore` 初期化・`OverlayWindow` 表示
  - `TranscriptionCoordinator` で権限準備と Start/Stop の通知購読
  - `.danmakuChunk` を受けて非同期INSERT
  - `.danmakuDumpLatest` で最新10件をコンソール出力

## 非機能改善
- DB I/O 非同期化によりメインスレッドブロック回避
- エラー時のログ出力強化
- 取得順の明確化でデバッグ性向上

## 互換性
- DBスキーマは追加・変更なし（既存互換）
- `.danmakuChunk` 通知の `text/startedAt/endedAt` コントラクト維持

## 既知の課題 / TODO（軽微〜将来）
- ウィンドウレベル切替: デバッグ用に `.screenSaver` へ切替するフック（常駐アプリ
と競合時の保険）
- 多ディスプレイ対応: 各 `NSScreen` ごとに `OverlayWindow` 複製が必要
- Prefsクランプ: セッター側でも範囲クランプして外部変更に堅牢化
- Dump出力: `ISO8601DateFormatter` で安定した時刻文字列へ
- DBバックアップ: メニューから `VACUUM INTO` 実行（簡易バックアップ）

## 受け入れ基準（現状）
- UIスレッド非ブロック: OK（DBキュー化）
- 取得順: OK（`ended_at DESC`）
- 設定の永続化＆ランタイム反映: OK
- Devメニュー（ダンプ）: OK
```
