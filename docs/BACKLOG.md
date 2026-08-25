# Trimlet development backlog

- Current milestone: Mac multi-range 0.3
- Updated: 2026-08-25
- Source: `HUMAN_CHECK.md`

優先度はP0（次回確認を妨げる）、P1（次回確認に必要）、P2（その後の改善）の順。

## Mac multi-range 0.3

### TRIM-010 — 複数の残す区間を編集する

- Priority: P0
- Status: Implemented; automated checks pass, human check pending
- Scope: integer timestamp segments, overlap rejection, selection, update, delete, output-order move, Undo/Redo

### TRIM-011 — 区間リストを連続プレビューする

- Priority: P0
- Status: Implemented; human timing check pending
- Scope: selected-segment preview, ordered sequence preview, gap skipping, final-OUT stop, manual-operation cancellation

### TRIM-012 — 複数区間を1本へ書き出す

- Priority: P0
- Status: Implemented; generated-media checks pass locally
- Scope: Accurate and Fast temporary segments, concat stage, combined progress, cancellation cleanup, output validation

### TRIM-013 — 音声ストリームを選択する

- Priority: P1
- Status: Implemented; multi-audio human check pending
- Scope: ffprobe stream inspection, Japanese display labels, absolute FFmpeg stream mapping

### TRIM-014 — 長尺向け専用タイムライン

- Priority: P1
- Status: Next after the 0.3 human check
- Scope: zoom, pan, segment-edge dragging, thumbnails or waveform, keyframe snapping

### TRIM-015 — Accurate出力ポリシーを製品化する

- Priority: P1
- Status: Open
- Scope: encoder usability probe, quality policy, VFR PTS, interlace, HDR/color/rotation metadata, diagnostics

### TRIM-016 — 区間作成の順序をUIだけで理解できるようにする

- Priority: P0
- Status: Implemented; human check pending
- Reported: 2026-08-25 human check showed that Add-before-IN/OUT and IN/OUT-before-Add were indistinguishable
- Scope: empty initial boundaries, numbered Start → End → Keep flow, always-visible output section, separate new/edit modes, post-add reset

## PoC 0.2

### TRIM-001 — 再生・停止状態を安定させる

- Priority: P0
- Status: Implemented in PoC 0.2; ready for human check
- Platform: Mac
- Problem: 再生→停止→再生→停止を繰り返すと、ボタンが無反応に見える場合がある。
- Likely cause: `isPlaying`の手動更新と、40 msごとの`AVPlayer.timeControlStatus`確認が競合している可能性がある。`play()`直後の`.waitingToPlayAtSpecifiedRate`を停止と解釈すると、表示状態とAVPlayerの実状態がずれる。

Tasks:

1. MP4、プロキシM2TS、シーク直後、終端付近で再現条件を記録する。
2. `isPlaying`を独立した正本にせず、AVPlayerの状態観測からUI状態を導出する。
3. `.paused`、`.waiting`、`.playing`を別状態として扱う。
4. ボタン連打中も重複命令や状態反転を失わないようにする。
5. 待機中は必要に応じて小さなバッファリング表示を出す。

Acceptance:

- 再生／停止を通常速度で50回交互に操作して無反応がない。
- 200〜300 ms間隔の連続操作でも最終操作と状態が一致する。
- シーク直後、IN/OUTプレビュー後、動画終端からの再生でも一致する。
- ボタンのアイコン、映像、内部状態が一致する。

### TRIM-002 — 書き出し・プロキシ生成の進捗を見せる

- Priority: P0
- Status: Implemented in PoC 0.2; ready for human check
- Platform: Shared behavior; Mac implementation first
- Problem: 短い動画では処理中表示を目視できず、長い処理時の表示も未評価。

Tasks:

1. FFmpegに`-progress`出力を設定し、`out_time_us`等を解析する。
2. 対象範囲の長さから0〜100%を計算する。
3. モード、処理対象、進捗バー、経過時間、キャンセルを含む非ブロッキング表示を追加する。
4. プロキシ生成にも同じ進捗モデルを適用する。
5. 短時間処理でも完了結果を最低1.5秒、またはユーザーが閉じるまで表示する。
6. 失敗時は短い説明と詳細ログへの導線を出す。

Acceptance:

- 10秒未満の処理でも開始と完了が認識できる。
- 5分以上のテスト動画で進捗が単調増加し、UIが固まらない。
- キャンセル操作が有効で、完了品に見える途中ファイルを残さない。
- 成功・失敗・キャンセルを視覚的に区別できる。
- FFmpegの終了コードが0でも、出力後検証で映像ストリームや妥当な長さを確認できなければ成功扱いしない。

### TRIM-003 — キーフレームとGOPを解析・表示する

- Priority: P1
- Status: Implemented for packet keyframes in PoC 0.2; two-hour stress test remains
- Platform: Shared data contract; native timeline rendering per platform
- Problem: 高速モードと正確モードの違いをタイムラインから判断できない。

Tasks:

1. ffprobeからキーフレームPTSを取得する。
2. 長尺動画でも全フレームをメモリへ展開しない索引形式を決める。
3. タイムラインにキーフレームの目盛りを表示する。
4. 表示密度が高い場合はズームや間引きを行う。
5. 凡例とツールチップで「高速切り出しに使える位置」を説明する。
6. 索引生成中の進捗とキャンセルをTRIM-002へ接続する。

Acceptance:

- テスト動画の既知キーフレーム位置と表示が一致する。
- 2時間動画でもタイムライン操作を阻害しない。
- 選択範囲表示とキーフレーム表示を同時に判別できる。
- MacとWindowsが同じキーフレームPTSデータを解釈できる。

### TRIM-004 — 高速モードの実切断候補を事前表示する

- Priority: P1
- Status: Implemented as an explicitly labeled candidate in PoC 0.2
- Depends on: TRIM-003
- Platform: Shared behavior
- Problem: 現在は「ずれる場合がある」という文章だけで、どこからどこまで出力されるか分からない。

Tasks:

1. IN/OUTに対して高速モードが使用する候補境界を計算する。
2. 指定範囲と高速出力候補範囲を色または補助線で比較表示する。
3. 差を時間とフレーム数で表示する。
4. 使用可能なキーフレームが範囲内にない場合は正確モードを推奨する。
5. 実際の書き出し後にffprobeで境界を確認し、予測との差を記録する。

Acceptance:

- 書き出し前に高速／正確の差を視覚的に説明できる。
- 予測境界と実出力境界が定義した許容差内で一致する。
- 映像ストリームが生成されない可能性のあるFast計画を成功扱いしない。

### TRIM-005 — 複数フレーム・時間単位移動を追加する

- Priority: P1
- Status: Implemented in PoC 0.2; ready for human check
- Platform: Shared behavior
- Problem: 1フレーム移動だけでは長い範囲の微調整に操作回数が多い。

Recommended first design:

- Left/Right: 1フレーム
- Shift + Left/Right: 10フレーム
- Option + Left/Right: 5秒
- 画面上にもマウス操作可能な対応ボタンまたは移動量メニューを用意する。

Rules:

- CFRの5秒移動は24/30/60/240 fps等の原本に自然に追従する。
- VFRの5秒移動はPTS基準とする。
- 複数フレーム移動はAVPlayerの結果を確認し、時刻表示を実位置へ同期する。
- 先頭・終端を越えない。

Acceptance:

- 24、30、60、240 fpsのテスト動画で5秒移動の結果が期待位置に一致する。
- 10フレーム移動を往復すると元のフレームへ戻る（CFR・破損なし入力）。
- キーボードと画面ボタンの結果が一致する。

### TRIM-006 — PoC 0.2回帰・ヒューマンチェック

- Priority: P1
- Status: Developer verification complete; user human check is the current gate
- Depends on: TRIM-001〜005
- Platform: Mac; shared cases documented for Windows

Test media:

- 8秒の既存MP4/M2TS
- 5分以上で進捗を確認できるMP4/M2TS
- 24/30/60/240 fpsの短いCFR動画
- 長いGOPを持つ動画
- VFR動画

Acceptance:

- 0.1で「問題なし」とされた項目を劣化させない。
- 再生ボタン、進捗表示、キーフレーム表示、移動操作を再評価できる。
- FastとAccurateの違いを、書き出し前に説明・比較できる。
- 結果を新しい日付のヒューマンチェック記録へ残す。

## Later

### TRIM-007 — P/Bフレーム詳細インスペクター

- Priority: P2
- キーフレーム表示だけで不足する場合に、選択位置周辺のI/P/Bフレーム種別、PTS/DTS、GOP番号を詳細表示する。
- 通常のタイムラインを情報過多にしないため、常時表示にはしない。

### TRIM-008 — 製品版エンコード計画

- Priority: P2
- `ENCODING_PLAN.md`に従い、FFmpeg更新、整数PTS、品質プリセット、インターレース、HDR、音声・メタデータ、出力後検証を実装する。
