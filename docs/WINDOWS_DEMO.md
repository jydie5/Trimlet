# スクリーンショット用デモ動画 / Screenshot demo footage

**開発・保守担当者向け。アプリのインストールや通常の利用には不要です。**
[開発ガイドへ戻る](../DEVELOPING.ja.md) · [利用ガイドを探している方はこちら](user-guide.ja.md)

READMEの画像は実アプリのスクリーンショットです。表示中の映像は自作の合成素材で、操作説明動画ではありません。

## 生成手順

FFmpeg（`gradients`、`drawtext`、`libx264`対応）をPATHに設定したWindowsで、リポジトリを取得し、ルートからPowerShellで実行します。

```powershell
.\scripts\create-windows-demo.ps1
```

既定では一時フォルダー内の `trimlet-demo/Color study.mp4` に30秒の映像を生成します。同名のデモファイルは上書きされます。出力先を変える場合：

```powershell
.\scripts\create-windows-demo.ps1 -OutputDirectory C:\TrimletDemo
```

表示された出力パスの動画をTrimletで開いてください。スクリプトをダブルクリックする必要はありません。アプリの起動ファイルではなく、スクリーンショット素材を作る開発用ツールです。

[生成スクリプトのソース（PowerShell）](../scripts/create-windows-demo.ps1)

## English

The screenshot uses original procedural footage, not a video tutorial. On Windows, install FFmpeg with the `gradients`, `drawtext`, and `libx264` features, clone the repository, and run the command above from its root in PowerShell. The script prints the generated 30-second MP4 path under your temporary directory. Existing demo output is overwritten. Open that MP4 in Trimlet. This script generates media; it does not launch or install the app.
