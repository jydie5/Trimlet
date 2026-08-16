# Mac開発・容量確認

- 確認日: 2026-08-14
- 機種: Apple Silicon Mac（arm64）
- macOS: 26.5.2

## 容量

確認時点の内蔵ストレージ空き容量は約146 GiBです。

現在のPoCが使っている容量の目安:

- `Trimlet.app`: 約516 KB
- Swiftビルドキャッシュ `.build`: 約693 MB
- 8秒のM2TSテストプロキシ: 約4 MB
- 5分10秒の進捗確認用MP4: 約41 MB

PoC開発には十分な空きがあります。長時間録画のプロキシと正確モードの出力は大きくなるため、実データ検証時は残量を確認します。現在の4 Mbpsプロキシ設定では、映像部分の単純計算で1時間あたり約1.8 GBが目安です。音声やコンテナ分の増加があります。

プロキシ保存場所:

```text
~/Library/Caches/Trimlet/Proxies
```

## 開発ツール

- Apple Swift 6.3: 利用可能
- macOS Command Line Tools: 利用可能
- FFmpeg / ffprobe: `/opt/homebrew/bin` に導入済み
- Xcodeアプリ本体: 未導入

Xcode本体がなくても現在のPoCはビルド・起動できます。今後、通常の`.xcodeproj`、GUIデバッガ、署名、配布設定を扱う段階ではXcodeを導入します。空き容量146 GiBで導入余地は十分あります。
