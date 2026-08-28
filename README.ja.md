# Trimlet

[English](README.md) | [日本語](README.ja.md)

必要なところだけ、すばやく正確に。

Trimletは、macOSとWindowsでそれぞれネイティブ実装する、軽量でフレーム正確な動画切り出しアプリです。

macOS版はSwiftUIによるBeta段階です。Windows版もC#／WinUI 3によるネイティブ実装として、同じ製品仕様とメディア処理契約に従って追従開発します。

## 目的

大容量動画をファイル全体ごとメモリへ読み込まずに開き、複数のIN／OUT区間を並べて1本のMP4へ書き出します。

操作は次の流れに絞ります。

1. 動画を開く、またはドロップする。
2. 必要な位置をすばやく探す。
3. IN点とOUT点を設定して必要区間を追加・並べ替える。
4. 区間を連続プレビューし、音声を選ぶ。
5. 高速モードまたはフレーム正確モードで1本に書き出す。

優先入力形式はMP4、MOV、M2TS、MTSです。

## 主な編集機能

- 1本の元動画から複数のサブクリップを作成し、編集シーケンス上で並べ替えて1本のMP4へ書き出せます。
- 作成中のIN／OUT範囲は紫、追加済みクリップは青、IN点は緑、OUT点は赤で区別します。
- 各クリップには代表サムネイル、編集できるクリップ名、IN–OUT時間を表示します。
- 左右キーで1フレーム、Shift＋左右キーで10フレーム、Option＋左右キーで5秒移動できます。
- `J`＝逆再生、`K`＝停止、`L`＝順再生のシャトル操作に対応し、`J`／`L`の連打で1倍、2倍、4倍、8倍へ速度を変更できます。
- `I`でIN点、`O`でOUT点を設定できます。ショートカットは対応する画面ボタンにも表示され、キーボード操作は必須ではありません。
- スライダーやトラックパッドで連続シークし、操作を終えた位置で正確に合わせます。
- 高速モードは可能な範囲で映像を再エンコードせず、フレーム正確モードはVideoToolboxによるハードウェア支援を優先して正確な境界を書き出します。
- 複数音声ストリームの選択、連続プレビュー、進捗表示、キャンセル、書き出し後の検証に対応します。

## 現在の状態

- macOS：ネイティブ`v0.3.0-beta.1`。複数区間、編集シーケンス、連続プレビュー、音声選択、複数区間の高速／正確書き出しを実装しています。
- Windows：ソース配布のEarly Access。ネイティブ再生、単一区間、音声ストリーム選択、検証付きの高速／正確書き出しまで実装済みで、次にMac Betaの複数区間と操作体系へ追従します。
- 同等性：動画を開く → IN／OUTを選ぶ → 書き出す、という基礎フローは揃っています。複数区間、J/K/L、高速スクラブ、自動プレビュー用プロキシ、可変フレームレート動画のPTS基準移動には差があります。
- macOS最新版：[v0.3.0-beta.1](https://github.com/jydie5/Trimlet/releases/tag/v0.3.0-beta.1)をMIT Licenseのソースのみで公開しています。

Windows Early Access：[v0.3.0-early-access.1](https://github.com/jydie5/Trimlet/releases/tag/v0.3.0-early-access.1)（ソースのみ。インストーラーやビルド済み実行ファイルはありません）

このリポジトリはFFmpeg、ffprobe、テスト動画、生成済みアプリを同梱・再配布しません。現在のPoCは利用者が別途インストールしたFFmpegを使用します。

## リポジトリ構成

```text
apps/macos/       SwiftUI／AVFoundationによるMac実装
apps/windows/     Windows実装用の作業領域
contracts/        OSに依存しないデータ・動作契約
docs/             製品、設計、検証、権利関係の記録
scripts/          ローカルビルドと検証用スクリプト
.github/          OS別CI、Issue、Pull Request設定
```

UI、再生API、ハードウェア制御のソースは共有しません。用語、タイムスタンプ規則、書き出しモード、エラー分類、テストケース、安全要件を共有します。

[リポジトリ構成の判断](docs/architecture/REPOSITORY_STRUCTURE.md)と[Mac／Windows共通契約](docs/PLATFORM_CONTRACT.md)を参照してください。

## macOS Betaを試す

必要なもの：

- Apple Silicon Mac
- Swift tools 6.1互換のSwift環境
- `/opt/homebrew/bin`または`/usr/local/bin`へ別途インストールした`ffmpeg`と`ffprobe`

`run-poc.command`をダブルクリックすると、ローカル用の`dist/Trimlet.app`をビルドして起動します。システム全体へのインストールや動画のアップロードは行いません。

コアチェック：

```bash
swift run --package-path apps/macos TrimletCoreChecks
swift run --package-path apps/macos TrimletIntegrationChecks
```

生成動画と`dist/`はGitの対象外です。

## Windows Early Accessを試す

必要なもの：

- Windows 10 build 17763以降
- .NET SDK 10.0.400
- `PATH`、`TRIMLET_FFMPEG`／`TRIMLET_FFPROBE`、またはビルド済みアプリの隣に置いた`ffmpeg`と`ffprobe`

PowerShellで実行します。

```powershell
git clone https://github.com/jydie5/Trimlet.git
Set-Location .\Trimlet
.\apps\windows\run-human-check.ps1
```

共有契約、テスト、合成動画による書き出しを検証してから、未パッケージの開発用アプリを起動します。[Windows Early Accessガイド](apps/windows/README.md)と[ヒューマンチェック手順](apps/windows/HUMAN_CHECK.md)を参照してください。

## Trimletの開発継続を支援する

TrimletはMIT Licenseの無料ソフトウェアです。役立った場合は、**[Buy Me a Coffeeで今後の開発を任意で支援](https://buymeacoffee.com/jydie5)**できます。

支援はコード署名、Windows／macOS実機検証、ビルドサービス、開発用AI・APIなどの費用に充てます。支援による機能解放、ライセンス変更、支援者の優先対応はありません。

費用をかけずに、Star、リリースの共有、再現手順付きの不具合報告、異なる実機でのテスト、コードや文書の改善でも支援できます。[カンパとその他の支援方法](DONATIONS.ja.md)および[閲覧状況と支援をどう測るか](docs/development/project-sustainability.ja.md)を参照してください。送金には、このリポジトリ内に掲載した公式リンクだけを利用してください。

## 主な文書

- [製品要件](docs/REQUIREMENTS.md)
- [設計・製品判断](docs/DECISIONS.md)
- [未決事項](docs/OPEN_QUESTIONS.md)
- [Mac／Windows共通契約](docs/PLATFORM_CONTRACT.md)
- [製品・インターフェース設計原則](docs/PRODUCT_DESIGN.md)
- [Windows Early Accessガイド](apps/windows/README.md)
- [Windows保守担当へのhandover](apps/windows/handover.md)
- [WindowsからmacOS担当へのhandover](apps/macos/WINDOWS_EARLY_ACCESS_HANDOVER.md)
- [v0.3.0 Beta 1リリースノート](docs/releases/v0.3.0-beta.1.md)
- [Mac PoCの範囲](docs/POC.md)
- [ヒューマンチェック手順](docs/HUMAN_CHECK.md)
- [検証環境](docs/ENVIRONMENT.md)
- [PoC検証記録](docs/VERIFICATION.md)
- [FFmpeg・正確モード設計](docs/ENCODING_PLAN.md)
- [公開前の権利・配布チェック](docs/legal/RELEASE_COMPLIANCE.md)
- [名称・商標の事前調査](docs/legal/TRADEMARK_SEARCH_2026-08-16.md)
- [ライセンス判断](docs/legal/LICENSE_DECISION.md)
- [開発バックログ](docs/BACKLOG.md)

## プライバシーと安全

動画処理はローカルで行います。アカウント、利用解析、テレメトリー、クラウドへの動画アップロードはありません。元動画は読み取り専用として扱い、書き出し結果を検証してから完成ファイルにします。

## ライセンス

Trimletのソースコードと文書は[MIT License](LICENSE)です。著作権表示は個人名ではなく`Trimlet contributors`という共同名義です。複製または主要部分へMITの表示を残す条件で、利用、改変、公開、再配布、販売などが認められます。

FFmpegは別プロジェクトであり、独自のライセンス条件があります。[第三者ソフトウェアに関する表示](THIRD_PARTY_NOTICES.md)を参照してください。
