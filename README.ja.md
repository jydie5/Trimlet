# Trimlet

[English](README.md) | [日本語](README.ja.md)

必要なところだけ、すばやく正確に。

Trimletは、macOSとWindowsでそれぞれネイティブ実装する、軽量でフレーム正確な動画切り出しアプリです。

macOS PoCはSwiftUIで実装済みです。Windows版はWindowsネイティブのAPIとC#を使用しながら、同じ製品仕様とメディア処理契約に従います。

## 目的

大容量動画をファイル全体ごとメモリへ読み込まずに開き、1つのIN／OUT範囲を指定してMP4へ書き出します。

操作は次の流れに絞ります。

1. 動画を開く、またはドロップする。
2. 必要な位置をすばやく探す。
3. IN点とOUT点を正確に設定する。
4. 高速モードまたはフレーム正確モードで書き出す。

優先入力形式はMP4、MOV、M2TS、MTSです。

## 現在の状態

- macOS：ネイティブPoC 0.2。次のヒューマンチェックが可能です。
- Windows：担当者向けの作業領域、共有契約、handoverを用意済み。アプリコードは未着手です。
- 公開：[v0.2.0-poc](https://github.com/jydie5/Trimlet/releases/tag/v0.2.0-poc)をMIT Licenseでソース公開しています。

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

## macOS PoCを試す

必要なもの：

- Apple Silicon Mac
- Swift tools 6.1互換のSwift環境
- `/opt/homebrew/bin`または`/usr/local/bin`へ別途インストールした`ffmpeg`と`ffprobe`

`run-poc.command`をダブルクリックすると、ローカル用の`dist/Trimlet.app`をビルドして起動します。システム全体へのインストールや動画のアップロードは行いません。

コアチェック：

```bash
swift run --package-path apps/macos TrimletCoreChecks
```

生成動画と`dist/`はGitの対象外です。

## Trimletの開発継続を支援する

TrimletはMIT Licenseの無料ソフトウェアです。役立った場合は、**[Buy Me a Coffeeで今後の開発を任意で支援](https://buymeacoffee.com/jydie5)**できます。

支援はコード署名、Windows／macOS実機検証、ビルドサービス、開発用AI・APIなどの費用に充てます。支援による機能解放、ライセンス変更、支援者の優先対応はありません。

費用をかけずに、Star、リリースの共有、再現手順付きの不具合報告、異なる実機でのテスト、コードや文書の改善でも支援できます。[カンパとその他の支援方法](DONATIONS.ja.md)および[閲覧状況と支援をどう測るか](docs/development/project-sustainability.ja.md)を参照してください。送金には、このリポジトリ内に掲載した公式リンクだけを利用してください。

## 主な文書

- [製品要件](docs/REQUIREMENTS.md)
- [設計・製品判断](docs/DECISIONS.md)
- [未決事項](docs/OPEN_QUESTIONS.md)
- [Mac／Windows共通契約](docs/PLATFORM_CONTRACT.md)
- [Windows実装の入口](apps/windows/README.md)
- [Windows作者へのhandover](apps/windows/handover.md)
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
