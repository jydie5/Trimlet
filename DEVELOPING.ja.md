# Trimletを改造する

[アプリ紹介](README.ja.md) · [English](DEVELOPING.md)

自分用の機能を加えたい人と、AIコーディングツールでフォークを育てたい人の入口です。アプリを使うだけなら[利用ガイド](docs/user-guide.ja.md)へ。

## 最初に決めること

1. GitHubでこのリポジトリをフォークし、自分のフォークをローカルに取得します。
2. 変更用のブランチを作り、Windows／Mac／両方のどこを変えるか決めます。
3. 「誰が何をできるようになるか」と、できたと判断する確認手順を書きます。
4. 対象OSの現状のビルドとテストを通してから変更します。

自分用の変更に本家の承認やPRは不要です。公開・再配布するときはMIT表記と依存ライブラリの条件を守ってください。本家にも提案する場合は[CONTRIBUTING](CONTRIBUTING.md)を参照してください。

## どこを読むか

| 変えたいもの | 主な場所 |
|---|---|
| Windowsの画面・操作 | `apps/windows/src/Trimlet.Windows/` |
| Windowsの編集データ・書き出し計画 | `apps/windows/src/Trimlet.Media/` |
| Windowsのファイル・動画処理連携 | `apps/windows/src/Trimlet.Platform.Windows/` |
| Macの画面・操作 | `apps/macos/Sources/Trimlet/` |
| Macの編集・動画処理のコア | `apps/macos/Sources/TrimletCore/` |
| 両OSの共通ルールと保存形式 | `contracts/`、[プラットフォーム契約](docs/PLATFORM_CONTRACT.md) |
| 画面や文言の判断基準 | [プロダクト設計](docs/PRODUCT_DESIGN.md) |

1本の動画から区間を集めるアプリです。元動画を変更しない、OUTは区間に含めない、保存形式と「高速／正確」の意味を不用意に変えない、という前提を確認してください。両OSのUIを同じコードや見た目にする必要はありません。

## Windowsで起動する

Windowsの開発環境、.NET SDK **10.0.400**（`apps/windows/global.json`）、別途FFmpeg／ffprobeが必要です。配布ZIPを使う場合とは違い、ソースのビルドにはSDKが必要です。

リポジトリのルートからPowerShellで実行します。

```powershell
.\apps\windows\run-human-check.ps1
```

このスクリプトは共有契約・テスト・合成素材の書き出しを確認してから、開発版をビルドして起動します。[詳細と個別コマンド](apps/windows/README.md)。

## Macで起動する

macOS 14以降、Swift tools 6.1対応の開発環境、別途FFmpeg／ffprobeが必要です。既存の検証環境はApple siliconです。ツールの配置は[環境記録](docs/ENVIRONMENT.md)を参照してください。

```bash
swift build --package-path apps/macos
swift run --package-path apps/macos TrimletCoreChecks
swift run --package-path apps/macos TrimletIntegrationChecks
scripts/validate-contracts.sh
```

アプリとして起動する場合は、ルートの `run-poc.command` を実行します。ローカルの `dist/Trimlet.app` を生成して開きます。名称はPoCですが現在のソースをビルドします。実行中のTrimletに未保存内容がある場合は先に確認してください。

## AIへの依頼例

以下を自分の目的に合わせて置き換えてください。AIに全資料を一度に読ませるより、対象と確認方法を絞ります。

> このTrimletのフォークに「追加したい機能」を実装してください。対象はWindowsのみです。
> まずDEVELOPING.ja.md、docs/PRODUCT_DESIGN.mdと対象コードを読み、変更箇所と確認方法を説明してください。
> 元動画の保護、既存プロジェクトの読込、他のOSの動作を壊さないでください。
> 共通契約を変える必要がある場合は、その理由と互換性への影響を先に示してください。
> テストを追加して実行し、起動できる状態まで進めてください。
> 最後に変更点、実行したテスト、私が画面で確認する手順、未確認事項をまとめてください。
> コミットの公開やリリースの作成は、私が依頼するまで行わないでください。

## 変更後の確認

- 変更したロジックのテストと共有契約の検証を実行する。
- 実アプリで新しい操作と従来の開く・範囲選択・保存・書き出しを確認する。
- 共通仕様を変えたら契約、フィクスチャ、両OSの担当者への引継ぎを更新する。
- 「実行して合格」「まだ未確認」を分ける。別OSやクリーン環境での動作を推測で合格にしない。
- 私物の動画、鍵、FFmpeg本体、生成済みビルドをコミットしない。

[Windows確認手順](apps/windows/HUMAN_CHECK.md) · [Mac確認手順](docs/HUMAN_CHECK.md) · [設計・引継ぎ・検証資料の索引](docs/README.md)

スクリーンショット素材を作る場合だけ[デモ素材の生成](docs/WINDOWS_DEMO.md)を参照します。利用者や通常の機能開発者が実行する必要はありません。
