# Trimlet

[English](README.md) | [日本語](README.ja.md)

必要なところだけ、すばやく正確に。

Trimletは、macOSとWindowsでそれぞれネイティブ実装する、軽量でフレーム正確な動画切り出しアプリです。

## アプリの作業画面

![Windows版Trimlet：動画プレビュー、独立したIN／OUT、名前付きクリップ、プロジェクト保存と書き出し](docs/images/windows-workspace-2026-09.png)

_自作の合成デモ動画を使用した、実行中のWindows開発版のスクリーンショットです。動画から切り出し、並べて書き出すまでの作業画面を紹介しています。[デモ動画の生成方法](scripts/create-windows-demo.ps1)。_

動画を開き、必要な区間を集め、順番を整え、プロジェクトを保存して1本のMP4に書き出せます。今回のWindows版には、`.trimlet`の保存・再開・名前を付けて保存、元動画の再指定、未保存確認と、IN／OUTを独立して動かせるタイムラインを追加しました。目盛りや帯の内部は再生位置の移動、外向きのつまみは境界の調整です。拡大・表示移動・範囲に合わせる操作では保存範囲を変更しません。

[今回の実装と検証](apps/windows/BUILD10_PARITY_RETURN.md) · [Windows版の起動](apps/windows/README.md) · [ヒューマンチェック](apps/windows/HUMAN_CHECK.md)

## 最新のMac UI/UX — 0.4開発版ビルド10

位置を探す → IN／OUTを設定 → 編集シーケンスへ追加。再生しなくても、見たい位置へ移動して区間を作れます。

<details>
<summary>Macタイムライン部品の描画画像（操作の詳細）</summary>

![最新Macタイムラインの描画部品：通常・極短区間・INのみ・先頭と末尾](docs/images/timeline-build10-light.png)

_実際の描画部品を合成の時刻でレンダリングした画像です。アプリ全体の画面写真ではありません。[ダーク表示](docs/images/timeline-build10-dark.png)。_

</details>

- **整理した作業画面：** 左に映像と再生操作、右にIN／OUTとクリップ詳細、下に編集シーケンス。保存・書き出しは上部へ集約しました。
- **再生位置と範囲を分離：** 目盛りや帯の内部でシークし、外向きのIN／OUTつまみで片側の境界だけを調整。短い範囲でも操作対象を分けています。
- **見える操作ヒント：** I／O、J／K／L、フレーム／5秒移動、二本指シーク、拡大・範囲に合わせる表示、操作対象と時刻の表示。
- **編集の保存・再開：** 確定したクリップと書き出し設定を`.trimlet`に保存し、再読込・元動画の再リンクができます。追加前のIN／OUT下書きは保存対象外です。
- **互換プレビュー：** Mac標準再生機構で読めない素材はH.264／AACプレビューを生成できます。VP9／OpusのMP4で確認済み。原本は変更しません。標準プレーヤー向けの保存には「フレーム正確」を選択してください。「高速」は元の映像コーデックを保持します。

ビルド10は最新の開発ソースであり、**新しいバイナリリリースではありません**。ビルド・Core／共有契約／書き出しテスト・描画確認は成功していますが、実機ジェスチャーの包括的なヒューマンチェックは残っています。Macの境界調整は公称fps刻みで、VFRの実フレーム索引ではありません。

[操作仕様](docs/TIMELINE_INTERACTION_2026-09-09.md) · [検証記録](docs/VERIFICATION.md) · [ヒューマンチェック](docs/HUMAN_CHECK.md) · [Windows向け引き継ぎ](apps/windows/TIMELINE_INTERACTION_HANDOVER.md) · [再生互換性の制限](docs/PLAYBACK_COMPATIBILITY_2026-09-09.md)

<details>
<summary>Windows Early Accessの画面（以前の受入済みUI）</summary>

![合成テスト動画を使用したWindows Early Access](docs/images/windows-multirange-early-access.jpg)

以前の受入済みUIの記録です。現在のWindows版の作業画面はページ上部で紹介しています。

</details>

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
- 両OSの現在の開発ソースでは、編集シーケンスを`.trimlet`プロジェクトとして保存・再開し、移動・変更された元動画を明示的に再リンクできます。

## 現在の状態

- macOS：公開版はネイティブ`v0.3.0-beta.1`。現在の0.4 Build 10開発候補には、プロジェクトの原子的な保存／読込、未保存表示、元動画の再リンク、改訂版ソースタイムラインを実装し、ヒューマンチェック待ちです。
- Windows：ソース配布のEarly Access。現在の開発ソースにプロジェクト保存・再開とビルド10のタイムライン操作を追加しました。停止中の範囲設定、独立したつまみ、ズーム、保存・再開、終了時の未保存確認は開発者が実アプリで確認済みです。今回追加分のヒューマンチェックは別途必要です。
- 同等性：共通プロジェクト形式v1と改訂された操作仕様は両OSに実装済みです。Windowsの実フレーム時刻による移動は維持しています。配布形式と幅広い実動画でのリリース検証は引き続きOS別の作業です。この更新は新しいバイナリの公開ではありません。
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
- [プロジェクト保存設計](docs/architecture/PROJECT_PERSISTENCE.md)
- [製品・インターフェース設計原則](docs/PRODUCT_DESIGN.md)
- [Windows Early Accessガイド](apps/windows/README.md)
- [Windows保守担当へのhandover](apps/windows/handover.md)
- [Windowsプロジェクト保存handover](apps/windows/PROJECT_PERSISTENCE_HANDOVER.md)
- [WindowsからmacOS担当へのhandover](apps/macos/WINDOWS_EARLY_ACCESS_HANDOVER.md)
- [Windows複数区間追従後のhandover](apps/macos/WINDOWS_MULTI_RANGE_HANDOVER.md)
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
- [Build 10ソースタイムライン操作仕様](docs/TIMELINE_INTERACTION_2026-09-09.md)

## プライバシーと安全

動画処理はローカルで行います。アカウント、利用解析、テレメトリー、クラウドへの動画アップロードはありません。元動画は読み取り専用として扱い、書き出し結果を検証してから完成ファイルにします。

## ライセンス

Trimletのソースコードと文書は[MIT License](LICENSE)です。著作権表示は個人名ではなく`Trimlet contributors`という共同名義です。複製または主要部分へMITの表示を残す条件で、利用、改変、公開、再配布、販売などが認められます。

FFmpegは別プロジェクトであり、独自のライセンス条件があります。[第三者ソフトウェアに関する表示](THIRD_PARTY_NOTICES.md)を参照してください。
