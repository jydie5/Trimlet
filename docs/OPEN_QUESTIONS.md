# Open questions

These decisions should be closed before the indicated milestone. They are intentionally not guessed in the requirements.

## Before creating the Xcode project

1. What is the minimum macOS version? This determines available SwiftUI and AVFoundation APIs.
2. Is the first distributable build signed outside the Mac App Store, or should the design satisfy Mac App Store sandboxing from day one?
3. Should the bundle identifier use a personal reverse-domain identifier or a new project/organization domain?
4. Should the project use an `.xcodeproj` application target with local Swift packages, or start as a simpler single target?

## Before implementing M2TS export

5. How is FFmpeg supplied: bundled universal/arm64 binary, downloaded dependency, or a user-installed executable?
6. Which exact FFmpeg configure flags and license profile are acceptable for GitHub releases?
7. For interlaced sources, should Accurate mode deinterlace automatically, ask each time, or preserve interlacing?
8. What should happen when an M2TS has multiple programs or ambiguous primary audio?
9. Which timestamp-repair strategy is safe for damaged or discontinuous transport streams?

## Before public MVP release

10. Resolved 2026-08-16: Trimlet source and documentation use the MIT License with `Trimlet contributors` as the collective copyright notice.
11. Is the public release source-only initially, or will GitHub Releases include a signed/notarized `.dmg`?
12. Should proxy creation start automatically or require confirmation with an estimated disk size?
13. How long should caches be retained, and should cleanup be automatic?
14. What measurable thresholds define acceptable open, seek, reverse-step, and export performance?
15. Is Japanese-only UI acceptable for the first tagged release, or is English required at launch?

## Cross-platform coordination

These questions do not block the Mac PoC, but Mac decisions should not silently decide them for Windows.

16. Which optional project-state fields should extend the shared integer timestamp/timescale interchange direction?
17. Must Fast and Accurate exports be byte-for-byte comparable, or only behaviorally equivalent within documented timing and codec tolerances?
18. Which keyboard shortcuts should be identical across platforms, and which should follow platform conventions?
19. Will FFmpeg builds on Mac and Windows use the same major version and configure profile?
20. Which Windows-native playback stack will satisfy the same seek and frame-step acceptance targets?

## Accurate export and FFmpeg

21. Which exact current FFmpeg release, source revision, and build configuration will be pinned for the first public binary test build?
22. What quality model replaces the PoC's fixed H.264 12 Mbps setting?
23. When should Accurate mode default to H.264, HEVC Main 10, or another codec?
24. What are the exact inclusive/exclusive semantics of IN and OUT in source PTS units?
25. Which inputs require `trim/atrim` filters instead of output seeking alone?
26. What deinterlace policy and output frame rate should be used for 1080i recordings?
27. How are HDR, color metadata, rotation, and sample aspect ratio preserved or converted?
28. Should hardware decode be enabled by default, selected after probing, or offered as a compatibility option?
29. What post-export ffprobe checks must pass before an output is finalized?
