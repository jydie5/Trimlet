# Public documentation policy

Updated: 2026-09-09, following the owner's request to separate app users from people extending an AI-assisted fork.

## Two entry paths

The root README is an app introduction, not a development diary. A reader without coding knowledge should understand what Trimlet does, see a whole-app screenshot, find the actual app download, know the important setup limitations and find help.

A separate development entry serves people who fork and extend Trimlet, including with AI. It provides a code map, reproducible setup, design/compatibility boundaries, tests and a bounded example task. It must not require reading every handover document to begin.

## Placement

- README / README.ja: product, screenshot, download, capabilities, development entry, help.
- User guides: first-run setup, ordinary operations, recovery. No compiler/test commands.
- DEVELOPING / DEVELOPING.ja: builds, code map, AI tasks, verification.
- CONTRIBUTING: optional upstream contribution expectations.
- docs/README: design, historical handovers, verification and release evidence.
- Screenshot-generation scripts and their instructions: maintainer material only, not README image captions or first-run guides.

Retain useful historical files and links; removing them from the front page is not a reason to erase evidence. Existing release binaries and checksum records must not be silently replaced for a documentation change.

## Review checks

1. Does the opening explain the app without internal build numbers, parity reports or implementation vocabulary?
2. Is the download a ready-to-run artifact, and is source-only availability clearly distinguished?
3. Are prerequisites and beta limitations visible before the user commits to setup?
4. Can a non-coder follow the user guide without a terminal?
5. Can a developer locate the affected code, design rules and tests?
6. Are English and Japanese routes equivalent?
7. Does a technical detail change the reader's next action? If not, move it to the relevant reference.

## Remaining product gap

The current Windows beta still requires external FFmpeg setup and is unsigned. Mac has no ready-to-run binary. Better documentation does not remove those barriers. A beginner-ready distribution needs separate implementation/release work; do not claim this documentation update completes that work.
