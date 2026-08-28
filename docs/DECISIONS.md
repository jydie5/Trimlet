# Technical and product decisions

This log records decisions that define Trimlet. Change a decision by adding a new entry rather than silently rewriting its history once implementation begins.

## Accepted

### D-001: Product name is Trimlet

- Date: 2026-08-14
- Status: Accepted for GitHub project use
- Reason: Short, memorable, format-independent, and aligned with a lightweight trimming utility.
- Preliminary collision check: No GitHub repository or account named Trimlet was found, and no prominent software product using the exact name was identified.
- Google check: Exact-name searches combined with video, editor, macOS, software, app, and GitHub terms found no existing video-editing or Mac software product named Trimlet. Results were primarily an unrelated health supplement, surnames, and general hair-trimming usage.
- Conclusion: Clear for use as this GitHub project's name, subject to the limitation below.
- Limitation: This is not a legal trademark clearance.

### D-002: Native Mac application

- Date: 2026-08-14
- Status: Accepted
- Decision: Use Swift 6 and SwiftUI. Do not build the MVP with React, Electron, or Tauri.
- Reason: Direct access to AVFoundation and native Apple silicon media acceleration is central to the product.

### D-003: Hybrid Apple and FFmpeg media stack

- Date: 2026-08-14
- Status: Accepted
- Decision: Use AVFoundation for playback, ffprobe for inspection, FFmpeg for export/conversion, and VideoToolbox for supported hardware encoding.
- Reason: AVFoundation provides native playback behavior; FFmpeg provides the input breadth needed for M2TS/MTS.

### D-004: External FFmpeg process for MVP

- Date: 2026-08-14
- Status: Accepted
- Decision: Invoke ffprobe and FFmpeg as managed child processes rather than linking FFmpeg libraries directly.
- Consequence: Process discovery, packaging, cancellation, progress parsing, and license compliance require dedicated design.

### D-005: One-range workflow

- Date: 2026-08-14
- Status: Accepted
- Decision: The MVP supports one source file and one IN/OUT range at a time.
- Reason: This preserves the single-purpose product and keeps timeline and export behavior testable.

### D-006: Two explicit export modes

- Date: 2026-08-14
- Status: Accepted
- Decision: Present Fast and Accurate modes as a user-visible choice.
- Consequence: Fast mode must explain keyframe-boundary limitations; Accurate mode prioritizes timestamps and may re-encode.

### D-007: Source safety over convenience

- Date: 2026-08-14
- Status: Accepted
- Decision: Never modify or overwrite source media. Export through a temporary file and finalize atomically where possible.

### D-008: Shared behavior, separate native implementations

- Date: 2026-08-14
- Status: Accepted
- Decision: Mac and Windows versions share product terminology, interaction semantics, timestamp rules, export modes, safety rules, and acceptance media, while using separate native implementations.
- Mac scope: This repository's active PoC work targets the native SwiftUI Mac application.
- Windows scope: A separate contributor implements Windows and uses `PLATFORM_CONTRACT.md` as the parity reference.
- Consequence: Documents distinguish shared behavior from platform adapters and avoid making AVFoundation or Swift types part of the product contract.

### D-009: PoC accurate export settings are provisional

- Date: 2026-08-14
- Status: Accepted
- Decision: The current `h264_videotoolbox`, 12 Mbps, AAC 256 kbps command proves the workflow and hardware encoder path, but is not the production encoding policy.
- Verified: Accurate seek is placed after input opening, CFR test output matched a requested 2.5-second range, and VideoToolbox encoding completed with software fallback disabled by default.
- Required follow-up: Adopt and pin a current FFmpeg release; move boundaries to integer PTS; derive encoding, interlace, HDR, audio, and metadata options from ffprobe results; and add post-export verification.
- Detail: See `ENCODING_PLAN.md`.

### D-010: One monorepo, separate native applications

- Date: 2026-08-16
- Status: Accepted; supersedes any implication in D-008 that Windows should use a different repository.
- Decision: Keep macOS under `apps/macos` and Windows under `apps/windows`. Do not share native UI or playback implementation code.
- Shared boundary: Product requirements, timestamp representation, export-plan semantics, error identifiers, fixtures, safety invariants, and release policy live at the repository root.
- Reason: The product and media behavior are still evolving together. One review and fixture history reduces cross-platform drift more effectively than duplicating specifications across repositories.
- Revisit: Separate repositories are justified only by distinct licenses/products, access controls, governance, or material repository/CI cost. If split, shared contracts move to a third versioned specification repository.

### D-011: Continue the Trimlet project name after official-database screening

- Date: 2026-08-16
- Status: Accepted for repository and development use; commercial clearance remains open.
- Evidence: J-PlatPat and USPTO exact-name searches returned no `Trimlet` record. TMview returned one expired Canadian class-7 figurative record for the literal partial match. J-PlatPat similar-pronunciation results include a class-9 `DigitalTriplet` registration.
- Decision: Continue using Trimlet for the GitHub repository and PoC. Do not represent the name as legally cleared or registered.
- Release condition: Re-run searches and obtain professional review of relevant similar marks before a commercial filing, paid distribution, or material branding investment.
- Detail: See `docs/legal/TRADEMARK_SEARCH_2026-08-16.md`.

### D-012: MIT-licensed software with optional donations

- Date: 2026-08-16
- Status: Accepted
- Decision: License Trimlet source code and documentation under MIT using `Trimlet contributors` as the collective copyright notice.
- Funding: Publish `https://buymeacoffee.com/jydie5` as the only current monetary support link, matching MangaCrisp.
- Invariant: Payment is never required, unlocks no feature, changes no license term, and gives no product or support priority.
- Reason: The author intends the application to be a free entry point for voluntary support and does not require personal attribution or royalties.

### D-013: First Windows native stack and developer packaging

- Date: 2026-08-20
- Status: Accepted for the first Windows human-check slice
- Decision: Use C# on .NET SDK 10.0.400, WinUI 3, and Windows App SDK 2.4.0. Target Windows SDK 26100 APIs while preserving Windows 10 build 17763 as the declared minimum.
- Playback: Use `Windows.Media.Playback.MediaPlayer` hosted by WinUI `MediaPlayerElement` for the first direct-preview slice.
- Localization: Use English (`en-US`) as fallback and provide equivalent Japanese (`ja-JP`) `.resw` resources from the first implementation.
- Packaging: Build an unpackaged, framework-dependent developer application for the first human check. Do not produce or imply a signed distributable binary.
- FFmpeg: Require separately installed `ffmpeg` and `ffprobe` executables for the developer slice; no third-party executable is added to the repository.
- Known limitation: Frame movement uses the inspected nominal rational frame rate. Source-PTS stepping for variable-frame-rate media and automatic preview proxies remain future work.

### D-014: Windows FFmpeg discovery, export safety, and H.264 selection

- Date: 2026-08-20
- Status: Accepted for the Windows human-check slice
- Discovery: Find `ffmpeg` and `ffprobe` through `TRIMLET_FFMPEG` / `TRIMLET_FFPROBE`, beside the application, or on `PATH`, and verify the executables before use.
- Process safety: Pass each argument through `ProcessStartInfo.ArgumentList`; never construct a shell command from media paths.
- Encoder selection: For Accurate mode, probe candidate Windows hardware encoders and software encoders with a real one-frame encode, selecting the first usable H.264 implementation.
- Output safety: Write a unique `.partial.mp4` in the chosen destination, validate its streams and duration with `ffprobe`, then atomically move it to the unique final name. Cancellation and failure remove the partial file.
- Interlace policy: Apply `bwdif` before Accurate H.264 output when the source is reported as interlaced. Fast mode keeps the original video stream.

### D-015: Publish the first Windows version as source-only Early Access

- Date: 2026-08-21
- Status: Accepted
- Release: `v0.3.0-early-access.1`
- Decision: Publish the implemented Windows workflow as a GitHub prerelease containing source code only. Do not attach an installer, application executable, FFmpeg/ffprobe binary, generated media, or developer cache.
- Parity claim: The primary open, navigate, IN/OUT, preview-range, and Fast/Accurate export workflow is aligned with the macOS PoC. Complete feature parity is not claimed because Windows lacks automatic preview proxies and source-PTS frame movement for variable-frame-rate media.
- Interface: Treat the application as a focused desktop work surface. Keep public taglines and general product explanations in README, release, or About material unless the text changes the user's next action. See `docs/PRODUCT_DESIGN.md`.
- Consequence: A future Windows binary remains blocked on packaging, dependency provenance and notices, original artwork, signing, an SBOM, and clean-machine verification.

### D-016: Add an ordered multi-range workflow without becoming a general NLE

- Date: 2026-08-24
- Status: Accepted; supersedes the one-range limit in D-005 while retaining its single-source intent
- Decision: Keep one source file, but allow multiple non-overlapping retained IN/OUT segments with explicit output order, undo/redo, sequence preview, audio selection, and one combined export.
- Boundary: Do not add multiple source clips, tracks, transitions, titles, effects, or independent audio editing in this milestone.
- Fast terminology: Use the user-facing label `Fast` / `高速`, not `lossless` / `無劣化`. Video is stream-copied when compatible, but keyframe expansion and possible audio conversion must remain visible.
- Shared contract: Store retained boundaries as integer timestamp values plus timescales and expose the edit-list contract to both native implementations.
- Detail: See `docs/milestones/MAC_MULTI_RANGE_0.3.md` and `docs/architecture/MULTI_RANGE_EDITING.md`.

### D-017: Make range creation a visible three-step state machine

- Date: 2026-08-25
- Status: Accepted after the first Mac 0.3 human check
- Problem: Showing draft IN/OUT, Add, and Update together did not reveal whether Add came before or after boundary selection. Preselecting the whole source made the ambiguity worse.
- Decision: New ranges use a visible three-stage creation flow; source open and successful Add leave both boundaries unset. Selecting an output card enters a separate edit state. D-018 defines the final user-visible labels as `1 IN → 2 OUT → 3 Add to Sequence` and Apply Trim.
- AviUtl reference: Preserve the useful relationship between time-axis objects, selection, and visible results, without importing a multi-layer NLE or general object system into Trimlet.

### D-018: Use editing terminology and direct sequence manipulation

- Date: 2026-08-25
- Status: Accepted after terminology review
- Decision: User-visible names are `Source Timeline` / `ソースタイムライン`, `Subclip` / `サブクリップ`, `Clip` / `クリップ`, `Editing Sequence` / `編集シーケンス`, and `Trim` / `トリム`. Internal `EditSegment` and `EditList` names remain implementation details.
- Interaction: Clips can be dragged to change their order in the contiguous editing sequence. Earlier/later buttons remain available for keyboard and accessibility use.
- Identity: A stable editable clip name is attached to the segment UUID. The default combines the source name and initial IN timecode. Reordering and trimming never rename the clip, and cards show no redundant position number.
- Card content: Show a representative frame near IN, clip name, and IN–OUT time. Thumbnail generation is an asynchronous presentation layer and never affects export.
- Reference: Final Cut Pro exposes filmstrips and clip-name display independently and supports renaming clips in its timeline index; Premiere exposes clip name and IN/OUT timecode as distinct display data. Trimlet adopts that information hierarchy without copying either application's full timeline surface.
- Sources: https://support.apple.com/guide/final-cut-pro/verb8e5d346/mac, https://support.apple.com/guide/final-cut-pro/view-your-project-in-the-timeline-index-ver4e30596/12.3/mac/15.6, https://helpx.adobe.com/premiere/desktop/organize-media/apply-labeling/timecode-display-options.html

### D-019: Separate clip selection from destructive trim editing

- Date: 2026-08-25
- Status: Accepted after a reproduced human-check failure
- Problem: Clicking a card previously loaded its boundaries into the shared editor. A later IN/OUT operation could therefore update that clip when the user believed they were adding another one, making the original appear deleted.
- Decision: Card click performs selection only. Preview, rename, reorder, and delete operate on selection. Existing IN/OUT values are loaded only after the explicit `Trim Edit` action, tracked by a separate trimming identifier.
- Safety invariant: Unless Trim Edit was explicitly chosen, the three-stage IN → OUT → Add flow creates a new clip and never changes an existing clip.
- Boundary: Arbitrary sequence-time placement, gaps, overlaps, and multiple tracks are not represented by the current model. They require a separate sequence-time milestone rather than overloading list order.

### D-020: Use distinct draft visuals, non-modal inspection, and conventional shuttle controls

- Date: 2026-08-26
- Status: Accepted after Mac interaction review
- Visual state: A valid uncommitted IN/OUT draft uses translucent purple plus a dashed boundary. Retained clips remain blue, IN remains green, OUT remains red, and Fast/keyframe information remains orange. Shape and legend reinforce color.
- Inspection: Once media is playable, automatic keyframe analysis runs without the full-screen operation panel. Running and failed states stay near the source timeline. Proxy generation and export keep cancellable progress; successful proxy completion auto-dismisses.
- Navigation: J/K/L form a signed four-level shuttle from reverse 8x through stop to forward 8x. Unsupported native rates fall back to paced tolerant seeks. Slider drag uses responsive tolerant seeks and release performs the exact final seek.
- Cross-platform: Windows uses the same visible meanings and shortcut state transitions with its native playback stack. It does not copy macOS playback code or UI layout.
- References: https://helpx.adobe.com/premiere/desktop/render-and-export/render-sequences-for-playback/play-clips-in-source-monitor.html, https://support.apple.com/guide/final-cut-pro/ver90ba4ef0/mac

### D-021: Publish the accepted Mac multi-range milestone as Beta 1

- Date: 2026-08-28
- Status: Accepted after the focused human interaction check
- Decision: Publish the current Mac milestone as the source-only prerelease `v0.3.0-beta.1`, merge its reviewed branch to `main`, and use it as the behavioral baseline for the next Windows parity turn.
- Distribution: Attach no application bundle, DMG, installer, FFmpeg/ffprobe binary, generated media, or developer build output. Production signing, notarization, dependency packaging, and clean-machine binary verification remain future gates.
- Scope: Beta status accepts the multi-range editing interaction and does not claim that broader M2TS, long-media, A/V sync, HDR/interlace, VFR, or cancellation evaluation is complete.
- Handover: Windows follows `apps/windows/handover.md` and `docs/PLATFORM_CONTRACT.md` with WinUI-native implementation choices.

### D-022: Adopt the Mac Beta multi-range contract in the Windows source

- Date: 2026-08-28
- Status: Accepted for Windows human-check candidate
- Decision: Replace the Windows single-range application state with the shared immutable edit-list model and implement the accepted Mac Beta interaction semantics using WinUI-native controls.
- Export: Plan and produce one temporary output per retained segment, then concatenate in edit-list order. Fast requires a valid keyframe candidate for every segment and keeps video stream copy; Accurate encodes every requested segment before concat. Validate the combined output before finalization and remove operation work on success, cancellation, or failure.
- Playback: Use native positive playback rates for forward J/K/L shuttle levels. Use wall-clock-paced seeks for reverse because this Windows playback path does not provide a reliable negative native playback rate. Keep direction and speed visible.
- Presentation: Generate representative thumbnails asynchronously into a session cache. Thumbnail failure never changes edit-list or export behavior.
- Gate: Developer checks may establish a parity candidate, but Windows release status does not advance until the user completes `apps/windows/HUMAN_CHECK.md`. Preview proxy, VFR source-PTS navigation, packaging, signing, and clean-machine binary verification remain separate work.
- Detail: See `docs/milestones/WINDOWS_MULTI_RANGE_0.3.md` and `apps/macos/WINDOWS_MULTI_RANGE_HANDOVER.md`.

## Proposed decisions awaiting validation

### P-001: Project structure

Proposed modules:

- `TrimletApp`: SwiftUI application and composition root.
- `MediaInspection`: ffprobe execution and typed metadata models.
- `Playback`: AVPlayer ownership, seek, frame step, and time observation.
- `Timeline`: range state, timestamp mapping, and thumbnails.
- `Proxy`: compatibility decision, proxy generation, cache identity, and cleanup.
- `Export`: export planning, FFmpeg argument generation, process progress, and cancellation.
- `ProjectStore`: optional restoration of source reference and range state.

Validate this split during the first playback and export prototypes before freezing package boundaries.

### P-002: Repository language

Proposed policy: user documentation in Japanese first, with the root README and identifiers in English to make the GitHub project approachable internationally.
