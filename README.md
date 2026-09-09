# Trimlet

[日本語](README.ja.md) · English

**Keep the moments you want from a video, then export them as one MP4.**

Trimlet is a small desktop video trimmer. Choose several ranges from one video, arrange them, and save your work for later. Your original video stays unchanged.

![Trimlet on Windows: video preview, selected ranges, and an editing sequence](docs/images/windows-workspace-2026-09.png)

*Windows version. The Mac interface differs.*

## Download and use

**[Download for Windows (x64 ZIP)](https://github.com/jydie5/Trimlet/releases/download/v0.4.0-beta.2/Trimlet-0.4.0-beta.2-win-x64.zip)** · [Getting started](docs/user-guide.md)

Windows **0.4.0 Beta 2** includes .NET. Choose **Video tools → Agree and prepare** on first use to download the video tools; no command or manual file setup is needed. This requires an internet connection and agreement to the displayed upstream terms. It remains an unsigned experimental release without clean-machine certification.

For **macOS**, there is no ready-to-run download yet. The source is available for people who can build it themselves; see [development setup](DEVELOPING.md). A GitHub “Source code” ZIP is not an installable app.

## What you can do

- Keep multiple parts of a single video and arrange their order.
- Preview the result and export one MP4.
- Choose **Fast** for speed or **Accurate** for more precise cut points.
- Save a project and continue editing later.

Open a video → mark its start and end → add the clip → repeat and arrange → export.

Common inputs include MP4, MOV, M2TS and MTS; playback and export support depend on the codecs inside the file. Video processing happens on your computer, without a Trimlet account or video-upload service.

## Make it your own

Want a feature for your own workflow? Fork Trimlet and change it, with or without an AI coding assistant.

**[Start developing](DEVELOPING.md)** — code map, build commands, design rules, tests, and an example AI task.

Private modifications do not require a pull request. If you want to contribute back, see [Contributing](CONTRIBUTING.md). The source is [MIT licensed](LICENSE); keep the license notice when redistributing it.

## Help and support

[Report a problem](https://github.com/jydie5/Trimlet/issues/new?template=bug_report.yml) · [Request a feature](https://github.com/jydie5/Trimlet/issues/new?template=feature_request.yml) · [Release notes](https://github.com/jydie5/Trimlet/releases)

You can describe problems in Japanese or English; coding knowledge is not required. Please do not post private videos or personal information.

[Optional support for development](DONATIONS.md) · [Third-party notices](THIRD_PARTY_NOTICES.md) · [Documentation index](docs/README.md)
