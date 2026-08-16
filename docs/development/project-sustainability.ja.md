# プロジェクトの継続と閲覧状況

[English](project-sustainability.md) | [日本語](project-sustainability.ja.md)

Trimletは個人で開発している、MIT Licenseの無料ソフトウェアです。この文書では、任意の支援をどう案内するか、アプリに利用解析を追加せずGitHub上の反応をどう確認するかを説明します。

## 方針

- 元動画、編集範囲、書き出し履歴、ファイルパス、利用状況を外部へ送信しません。
- 支援による機能解放、ライセンス変更、優先対応、動画処理結果への影響はありません。
- 金銭的な支援と、それ以外の協力を同じように歓迎します。
- 支援先は、このリポジトリに掲載したリンクだけを公式とします。
- 支援案内は編集操作より控えめにし、書き出しを妨げません。

## 支援への導線

英語／日本語READMEでは、任意の支援リンクを利用方法・リリース案内の近くに掲載します。`.github/FUNDING.yml`によってGitHubのSponsorボタンにも同じBuy Me a Coffeeアカウントを表示します。Mac PoCでは画面下部に小さな「開発を応援」リンクを置きます。将来のWindows版も、日英リソースを使って同じ副次的な導線を用意します。

支援はコード署名、Windows／macOS実機検証、ビルドサービス、開発用AI・APIなどの費用に充てます。Starや共有、合成動画を使った再現可能な不具合報告、異なるハードウェアでのテスト、コードや文書の改善も重要な支援です。

## GitHubで確認できること

管理者は**Insights > Traffic**で、直近14日間のリポジトリ表示数、ユニーク訪問者、full clone数、ユニークcloner数を確認できます。cloneには開発環境や自動処理が含まれる場合があり、インストール数や利用者数とは一致しません。

GitHub Releaseの各assetには累計`download_count`があります。現在のソースのみのPoCにはバイナリassetがないため、ソースアーカイブの取得数をアプリ利用数として扱えません。将来バイナリを添付しても、取得回数はユニーク人数、起動成功数、継続利用者数ではありません。

Star、fork、issue、pull requestも反応を見る材料ですが、いずれもアクティブ利用者数ではありません。その数字を得るためだけに動画やアプリの利用解析を追加しません。

## メンテナー向け確認手順

認証済みのGitHub CLIで、次のコマンドから再現可能なスナップショットを取得できます。

```bash
gh api repos/jydie5/Trimlet/traffic/views
gh api repos/jydie5/Trimlet/traffic/clones
gh api repos/jydie5/Trimlet/releases --paginate \
  --jq '.[] | .assets[] | [.name, .download_count] | @tsv'
gh repo view jydie5/Trimlet \
  --json stargazerCount,forkCount,watchers,issues
```

変動するカウンターをREADMEに置かず、定期的に比較します。数値はプロジェクト活動の目安であり、利用者数として公表しません。
