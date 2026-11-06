# Preview candidate validation

November 6, 2026. The previous session stopped with an uncommitted creator-toolkit
checkpoint, not a frozen or published release. This record separates development
checks from release gates. The target preview remains `0.1.0-alpha.1`.

## Integrated checkpoint

- White-balance sampling with persistent channel gains and shared rendering.
- Explicit caption word intervals and rendered highlighting. Text edits clear old
  intervals; split/trim/retime preserve the original timing clock.
- Crop/rotation motion and selected motion-key copy/paste; numeric text, drawing
  and effect curves with split/retime/persistence coverage.
- Monitor-only metronome, subdivisions and gain. Clicks never enter exports.
- Project schema 11 with older-schema migration and future-version rejection.

The first clean full run passes **343 tests across 15 suites**, with native media
integration and the pinned helpers enabled (60.985 seconds). Review then found
that removing animated effects retained curves targeting deleted IDs. The fix
removes only those orphaned effect curves, and keeps visual animation on the video
when detaching audio. Two new regressions pass, including one-action undo and
continued rejection of unrelated invalid curves. A subsequent full run passes 346 tests across 15 suites in 62.593 seconds.

## Distribution paths

The README source path builds `dist/Life Editor.app` from Swift sources using
Apple-native decoding. It does not download dependencies or silently search PATH
for media helpers. `.local-helpers` is ignored and is absent from a fresh clone.
Optional pinned FFmpeg/ffprobe must be built separately using the documented
helper script. A development package made on the maintainer's machine can include
both helpers, matching source, license notices and capability inventory.

The development app is ad-hoc signed and not notarized. This is not a consumer
Gatekeeper installation. The qualified public path can be source-first; no
security-bypass instructions or owner credentials are part of this validation.

## Installation and release checks

A clean local clone at `fb44660`, with no `.local-helpers` and no build cache,
passes the README optimized source build in 88.29 seconds. Its app has no Helpers
directory and launches with the helper override unset. This is a clean source
checkout on the existing macOS account, not a new-machine/Gatekeeper test.

The development package at that commit passes arm64/ad-hoc signature checks,
per-file manifest verification after ZIP extraction, and archive checksum checks.
Its manifest reports schema 11, ad-hoc signing, no notarization and both helpers.
All 36 payload files are covered. A pristine extracted app launches; a Matroska
fixture imports with no helper environment override and produces its conversion
sidecar. Matching helper source, licenses, notices, protocol/configuration and
system-only linkage checks pass. Inventory generation was performed on a separate
extraction; it writes files, so that inspected copy is not the pristine signed app.

The default 1280 × 800 workspace was visibly inspected at Retina scale. Native
frame stepping, viewer-focus switching, undo/redo and import/open dialogs were
exercised. A corrupt movie reports an error while retaining the existing title.
A 120-second title export was cancelled after progress began: the existing target
and saved project retain identical SHA-256 hashes, and no temporary export remains.
The unwritable-destination native regression independently proves actual write
denial, unchanged destination/project bytes and cleanup.

Several editor instances were already running. The long cancellation test used
a separately identified, re-signed copy of the same build to avoid LaunchServices
instance ambiguity; it is running-app evidence, not a byte-identical package test.
Early UI attempts lost foreground activation or timed out after file dialogs.
No reconstructed UI screenshot is used or published. This is a basic keyboard
smoke pass, not complete keyboard/VoiceOver acceptance. Earlier combined editing
and multicam workflows remain documented in [the app audit](MANUAL-WORKFLOW-AUDIT.md).

Hosted CI for `fb44660` passed tests but rejected the optimized build on Xcode
16.4/macOS SDK 15.5: white-balance opacity probing awaited non-Sendable AVAssetTrack
objects from the main actor. The pure source probe now runs nonisolated and returns
only a Boolean. Local targeted white-balance checks pass. That candidate is
superseded; publication requires a successful CI/native run and newly generated
archives at the corrected frozen commit. The release tag and manifests identify
that exact commit. The ad-hoc app archive remains a local development artifact;
the public distribution is source-first.

## Remaining full-product gates

Real on-device speech, full VoiceOver/accessibility, mixed/VFR/HDR coverage, full
disk/disconnected-drive behavior, M1 16 GB performance and musician/student
usability remain open. Synthetic fixtures do not close real-footage usability.
