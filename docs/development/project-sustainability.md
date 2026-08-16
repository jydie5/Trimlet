# Project sustainability and reach

[English](project-sustainability.md) | [日本語](project-sustainability.ja.md)

Trimlet is independent, free MIT-licensed software. This document explains how optional support is presented and how project reach is measured without adding analytics to the application.

## Principles

- Trimlet does not upload source videos, edit ranges, export history, file paths, or usage analytics.
- Payment does not unlock features, change the license, create priority, or influence media results.
- Financial and non-financial contributions are both useful.
- Funding links are authoritative only when published in this repository.
- Support messaging remains secondary to the editing workflow and never interrupts export.

## Support paths

The English and Japanese READMEs place the optional support link near the usage and release information. `.github/FUNDING.yml` enables GitHub's Sponsor button for the same Buy Me a Coffee account. The macOS PoC includes a small `Support development` link in its status area. The future Windows application should expose the same secondary action using localized resources.

Financial support helps with code signing, Windows/macOS hardware validation, build services, and development AI/API usage. People can also help by starring or sharing the repository, reporting reproducible bugs with synthetic media, testing on different hardware, and improving code or documentation.

## What GitHub can show

Repository administrators can use **Insights > Traffic** for rolling 14-day repository views, unique visitors, full clones, and unique cloners. A clone is not an installation or an active user; development machines and automation may be included.

GitHub Release assets expose a cumulative `download_count`. The source-only PoC has no binary asset, so source archive downloads are not a reliable application-use measure. Future binary asset counts will still represent downloads—not unique people, successful launches, or continued use.

Stars, forks, issues, and pull requests are useful engagement signals, but none is an active-user count. Trimlet will not add media or product telemetry merely to obtain that number.

## Maintainer check

Authenticated GitHub CLI commands can provide a reproducible snapshot:

```bash
gh api repos/jydie5/Trimlet/traffic/views
gh api repos/jydie5/Trimlet/traffic/clones
gh api repos/jydie5/Trimlet/releases --paginate \
  --jq '.[] | .assets[] | [.name, .download_count] | @tsv'
gh repo view jydie5/Trimlet \
  --json stargazerCount,forkCount,watchers,issues
```

Review these signals periodically rather than placing volatile counters in the README. Treat them as project activity, not as claims about the number of users.
