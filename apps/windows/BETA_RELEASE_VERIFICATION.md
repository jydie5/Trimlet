# Windows portable Beta 1 verification

Date: 2026-09-09. Version: `0.4.0-beta.1`, Windows x64 only.

## Artifact

- Built with .NET SDK 10.0.400, Release, win-x64, .NET and Windows App SDK self-contained, trimming disabled.
- ZIP: `Trimlet-0.4.0-beta.1-win-x64.zip`, 109,028,043 bytes.
- SHA-256: `daf4725a1734e6f76e56d188ad139bcbdbcf60b267be4dea8a7f70712c24be10`.
- Reproduction: `scripts/publish-windows-beta.ps1`; ZIP bytes can differ across rebuilds, so verify the published checksum rather than claiming byte-reproducibility.
- Includes compiled `Trimlet.Windows.pri`. Initial publish inspection found this missing; the project now explicitly includes it, and packaging rejects missing required resources/runtime DLLs.
- Includes upstream license/notice files and package metadata, resolved dependency inventory (including .NET runtime 10.0.11) and a per-file hash manifest. No FFmpeg/ffprobe or demo media is included.

## Actual archive checks

- Extracted the finished ZIP to a separate directory. All 568 manifest entries matched SHA-256.
- Launched the extracted EXE from a different working directory, with `DOTNET_ROOT` and `DOTNET_ROOT_X64` set to a nonexistent directory and multilevel lookup disabled.
- Process modules confirmed `hostfxr.dll`, `coreclr.dll` and `Microsoft.UI.Xaml.dll` were loaded from the extracted archive directory. No .NET-install prompt appeared.
- Native UI loaded the synthetic three-clip project, preview and thumbnails; Ctrl+S saved successfully.
- Exported the three 5-second ranges through the native UI using separately installed FFmpeg 6.1. Completion reached 100%; independent ffprobe reported H.264 1280×720, AAC, 15.064 seconds (container/audio padding included).
- Solution tests: 5 contract + 30 media tests passed.
- Shared contract validation and source readiness passed.
- Integration checks passed: Fast/Accurate, reordered multi-range and non-default audio, VFR timestamps, validated/reused M2TS/AC-3 proxy, Unicode/space/quote paths, safe output finalization.
- Windows CI also builds the self-contained archive using the same packaging script.

## Not established by these checks

This is a developer-machine smoke test, **not** clean-machine certification or comprehensive user acceptance. Original release artwork, signing, clean-machine/Windows 10/ARM64, physical trackpad/DPI/theme, expanded relinking and broad real-media/HDR/interlaced cases remain pending. This unsigned experimental beta does not complete the production release gate. No Mac binary is attached; Mac source remains available without changing the prior Mac beta tag.
