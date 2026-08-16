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
