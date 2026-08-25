# Trimlet product requirements

- Status: Draft 0.2
- Updated: 2026-08-25
- Target: Shared product behavior and the native Mac multi-range milestone

## 1. Product definition

Trimlet is a focused native desktop utility for quickly extracting one or more useful sections from one large video file. It combines simple IN/OUT marking with an ordered edit list and two export modes: fast video stream-copy cutting and frame-accurate encoding.

The Windows version is planned as a separate implementation by another team member. Unless a requirement is explicitly labeled Mac-only, functional behavior in this document is the shared product target for both platforms. Platform-specific implementation details are defined separately.

The product is successful when a user can open a multi-gigabyte recording, collect several useful ranges without learning a full video editor, preview their sequence, and obtain one usable MP4 without risking the source file.

## 2. Target users

Primary users:

- People who need to extract scenes from long camera or recorder files.
- Users handling M2TS/MTS recordings who want a convenient MP4 output.
- Users who find Final Cut Pro, DaVinci Resolve, or similar editors excessive for simple trimming.

The MVP does not target multi-track editors, colorists, motion-graphics creators, or collaborative production teams.

## 3. Mac implementation environment

- macOS on Apple silicon, M1 or later.
- Minimum macOS version: undecided; choose after API and test-device review.
- Native arm64 build.
- Offline operation. Source media is never uploaded.
- User interface languages for MVP: Japanese first; English-ready strings are required.

## 4. Primary workflow

1. The user opens or drops one local video file.
2. Trimlet inspects its streams and playback compatibility.
3. The video becomes operable as soon as practical.
4. If direct playback is unsuitable, Trimlet offers or starts proxy generation according to the chosen policy.
5. The user plays, seeks, scrubs, or steps frame by frame.
6. The user marks an IN point and an OUT point and adds that subclip to the editing sequence.
7. The user repeats marking as needed, then trims, removes, or reorders clips.
8. Trimlet shows every clip, total output duration, and a continuous sequence preview.
9. The user chooses Fast or Accurate export.
10. Trimlet joins the ordered retained ranges into one new MP4, showing progress and allowing cancellation.
11. On success, Trimlet validates and reveals the output in Finder or offers to open it.

## 5. MVP functional requirements

Requirement keywords follow MUST, SHOULD, and MAY.

### 5.1 File opening and inspection

- FR-001: The app MUST accept files through an Open dialog and drag and drop.
- FR-002: The MVP MUST accept MP4, MOV, M2TS, and MTS containers when their streams are otherwise supported.
- FR-003: The app MUST inspect container, duration, dimensions, nominal frame rate, video codec, audio streams, pixel format, and interlace indicators.
- FR-004: The app MUST NOT load the complete source file into memory.
- FR-005: Unsupported or unreadable files MUST produce an actionable error without terminating the app.
- FR-006: The source file MUST remain read-only from Trimlet's perspective.
- FR-007: The app SHOULD display basic media information in a compact inspector.

### 5.2 Playback and navigation

- FR-010: The app MUST provide play and pause.
- FR-011: The app MUST provide timeline seeking and scrubbing.
- FR-012: The app MUST step one displayed frame forward and backward.
- FR-013: Left and Right Arrow MUST step one frame while paused.
- FR-014: The app MUST display current position and total duration.
- FR-015: Time display MUST support `HH:MM:SS:FF` for constant-frame-rate media.
- FR-016: For variable-frame-rate media, internal positions MUST be stored by timestamp rather than by a calculated frame number.
- FR-017: The app SHOULD provide short jump backward and forward commands.
- FR-018: The UI MUST remain responsive during inspection, proxy creation, seeking, and export.

### 5.3 Range selection

- FR-020: The app MUST provide one trim editor used to create a subclip or trim an existing clip. New-subclip mode MUST begin with both boundaries unset rather than implying that the entire source is selected.
- FR-021: New-subclip mode MUST present the primary workflow in visible order: `1. IN point`, `2. OUT point`, `3. add to sequence`. The user MUST also be able to set IN and OUT with keyboard shortcuts.
- FR-022: The app MUST maintain an editing sequence containing zero or more ordered clips.
- FR-023: Every retained range MUST be visible on the source timeline and as a compact clip card in the editing sequence.
- FR-023A: Every new clip MUST receive a stable incremental label such as `Clip 001`. The UI MUST display sequence position separately so reordering never makes a clip appear to change identity.
- FR-024: A segment MUST be rejected when IN is not earlier than OUT, lies outside the source, or overlaps another retained source range.
- FR-025: The app MUST show draft duration, each segment duration, and total output duration.
- FR-026: Retained range positions MUST be stored using integer source-media timestamps plus a timescale; floating-point seconds are a playback adapter only.
- FR-027: The user MUST be able to add, select, trim, remove, and reorder clips.
- FR-027A: The user MUST be able to reorder clips directly by dragging them in the editing sequence. Visible earlier/later controls MUST remain as keyboard and accessibility alternatives.
- FR-028: Edit-list mutations MUST support undo and redo without changing the source file.
- FR-029: The user MUST be able to preview one retained range and continuously preview the ordered edit list, skipping gaps between retained ranges.
- FR-029A: After adding a new subclip, the editor MUST return to an empty new-subclip state. Selecting a clip MUST enter a visibly distinct trim state in which the primary action is Apply Trim, never Add to Sequence.
- FR-029B: A representative thumbnail near the clip IN point SHOULD be added to each clip card after the asynchronous thumbnail cache and long-media performance policy are defined.

### 5.4 Proxy handling

- FR-030: Trimlet MUST first determine whether direct AVFoundation playback is practical.
- FR-031: When direct playback is unsupported or unreliable, Trimlet MUST be able to create a lightweight editing proxy.
- FR-032: A proxy MUST be used only for preview and navigation; final export MUST use the source media.
- FR-033: Proxy progress and cancellation MUST be available.
- FR-034: The app MUST show the location and disk usage of generated proxies and caches.
- FR-035: The user MUST be able to remove generated proxies and caches.
- FR-036: Cache identity SHOULD include source path, size, modification date, and relevant stream properties so stale proxies are not reused.

### 5.5 Export

- FR-040: The MVP MUST export an MP4 file.
- FR-041: Fast mode MUST copy compatible video streams without re-encoding when possible.
- FR-042: Fast mode MAY convert only the audio stream, such as AC-3 to AAC, when MP4 compatibility requires it.
- FR-043: The UI MUST explain that Fast mode can move a cut to a nearby keyframe.
- FR-044: Accurate mode MUST prioritize the selected timestamps and re-encode video when required.
- FR-045: Accurate mode MUST use VideoToolbox acceleration when compatible with the source and selected output.
- FR-046: H.264 video and AAC audio MUST be the default accurate-output combination.
- FR-047: HEVC output SHOULD be an option, not the default.
- FR-048: Output SHOULD preserve source resolution, frame rate, aspect ratio, rotation, and color metadata when technically valid.
- FR-049: The app MUST display export progress, status, errors, and a Cancel action.
- FR-050: Export MUST write to a temporary file and rename it to the final name only after successful completion.
- FR-051: Trimlet MUST NOT overwrite the source file.
- FR-052: If the requested output exists, the app MUST ask for another name or receive explicit replacement confirmation.
- FR-053: A cancelled or failed export MUST NOT leave a file that appears complete.
- FR-054: The user MUST be able to choose the primary audio stream for M2TS/MTS input when more than one is present.
- FR-055: Accurate mode MUST join every retained range, in edit-list order, into one H.264/AAC MP4.
- FR-056: Fast mode MUST join every retained range, in edit-list order, without video re-encoding when all stages are stream-copy compatible.
- FR-057: Fast mode MUST display a keyframe-expanded candidate for every retained range and MUST refuse a misleading lossless claim when a valid stream-copy plan cannot be formed.
- FR-058: Multi-range export MUST keep audio continuous across segment boundaries and validate the combined duration against the sum of retained ranges or Fast candidates.
- FR-059: Exporting each retained range as a separate file MAY be added later; it is not required for this milestone.

### 5.6 M2TS/MTS behavior

- FR-060: Inspection MUST detect the primary video stream, available audio streams, subtitle presence, timestamp anomalies, and interlace indicators where reported.
- FR-061: The MVP MUST support common H.264, HEVC, and MPEG-2 Video inputs through direct playback or proxy generation.
- FR-062: The MVP MUST handle common AAC, AC-3, E-AC-3, and PCM input audio through copying or conversion.
- FR-063: When interlaced input is detected, the app MUST make the condition visible to the user.
- FR-064: The exact deinterlace policy remains a release-blocking decision for Accurate mode.
- FR-065: FFmpeg command construction MUST be derived from inspected stream properties rather than fixed solely by file extension.

### 5.7 Errors and recovery

- FR-070: User-facing errors MUST summarize what failed and provide a useful next action.
- FR-071: Detailed FFmpeg/ffprobe logs SHOULD be available through a diagnostics view or exported log file.
- FR-072: Relaunch after a crash MUST NOT damage the source or a previously completed output.
- FR-073: Temporary files from interrupted work SHOULD be detected and offered for cleanup.

## 6. Non-functional requirements

### Performance

- NFR-001: Opening a supported local MP4/MOV must not scale memory usage with total file size.
- NFR-002: The first usable UI should appear before optional thumbnail or proxy work completes.
- NFR-003: Playback controls should respond within 100 ms when no seek or decode work is required.
- NFR-004: Frame stepping and arbitrary seek targets will receive measurable thresholds after prototype benchmarking.
- NFR-005: CPU-heavy and file-processing work MUST run outside the main UI actor.

### Reliability and safety

- NFR-010: Source media MUST never be modified, renamed, moved, or deleted.
- NFR-011: All tool processes MUST support cancellation and termination cleanup.
- NFR-012: Paths containing spaces, Unicode, and shell metacharacters MUST be handled without shell interpolation.
- NFR-013: FFmpeg and ffprobe MUST be launched with argument arrays, not a user-derived shell command string.
- NFR-014: Security-scoped file access MUST be handled correctly if App Sandbox is enabled.

### Privacy

- NFR-020: Media processing MUST be local by default.
- NFR-021: The MVP MUST contain no analytics, account, cloud upload, or tracking requirement.

### Accessibility and usability

- NFR-030: Every essential action MUST be available by mouse and keyboard.
- NFR-031: Controls MUST have accessible labels and usable keyboard focus order.
- NFR-032: Status MUST not rely on color alone.
- NFR-033: Destructive cleanup actions MUST identify what will be removed.

## 7. MVP acceptance scenarios

The MVP is complete only when all applicable scenarios pass on an Apple silicon Mac:

1. Open a 5 GB or larger H.264 MP4, play it, scrub it, and step in both directions without loading the full file into memory.
2. Open a 4K HEVC MOV/MP4 and perform the primary workflow with usable playback.
3. Mark a range with keyboard controls and export it in Fast mode.
4. Export the same range in Accurate mode and verify the first and last intended frames within the documented boundary behavior.
5. Open a 1080i M2TS with AC-3 audio, create a proxy when needed, select its main audio stream, and export a synchronized H.264/AAC MP4.
6. Cancel proxy generation and export; confirm that the app remains usable and no apparently complete output is left behind.
7. Attempt to export over the source and confirm that the app prevents it.
8. Open a broken or unsupported file and receive a recoverable, understandable error.
9. Add at least three non-overlapping ranges in a non-chronological edit order, continuously preview them, and export one combined file in Accurate mode.
10. Export the same three ranges in Fast mode, see the candidate boundary difference for each range, and verify the combined output order and duration.
11. Select a non-default audio stream from a multi-audio source and confirm that the chosen stream is present in the combined output.
12. Add, update, remove, reorder, undo, and redo ranges without changing the source file or losing playback responsiveness.

## 8. Explicitly out of scope for MVP

- Multi-track timeline editing.
- Joining multiple source clips.
- Transitions, titles, effects, filters, and color correction.
- Audio mixing or independent audio trimming.
- Multiple source files, a multi-track timeline, or a cross-source batch queue.
- Subtitle editing or burn-in.
- Smart rendering that re-encodes only boundary GOPs.
- Cloud storage, collaboration, user accounts, and telemetry.
- Sharing native UI, playback, or hardware-encoder source code between macOS and Windows. The Windows application lives in this repository but remains a separate native implementation.
- Linux, Intel Mac, iPhone, and iPad builds.
- Plug-in architecture.

## 9. Validation media matrix

Test media must include:

- H.264 MP4 larger than 5 GB.
- 4K HEVC MP4 or MOV.
- 1080i and 1080p M2TS.
- M2TS containing AC-3 audio.
- 29.97 fps and 59.94 fps recordings.
- Variable-frame-rate input.
- Long-GOP input.
- A recording with timestamp discontinuity or a damaged opening GOP.
- File and parent-directory names containing Japanese, spaces, quotes, and emoji.

For each representative file, record open-to-usable time, seek time, forward and backward frame-step time, memory peak, CPU/GPU use, export speed, A/V sync, and actual cut boundary.

## 10. Definition of done for a public MVP

- All MUST requirements and acceptance scenarios pass or have a documented platform limitation.
- A clean Mac can build the project using documented steps.
- Automated tests cover media inspection parsing, export planning, timestamp/range validation, and process cancellation.
- At least the validation media matrix has a recorded test report without committing copyrighted test media.
- FFmpeg build configuration, license notices, source-offer obligations, and redistribution method are documented.
- Application license and contributor terms are selected.
- README includes installation, supported formats, limitations, privacy behavior, and known issues.
