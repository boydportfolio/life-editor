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
continued rejection of unrelated invalid curves. A final candidate run is required.

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

## Open gates

Fresh source build/first launch, extracted package launch, exact candidate CI/native
checks, archive payload/checksum verification and visible keyboard/workspace and
failure smoke checks must be recorded before publication. The manual November 4
workflow evidence remains in [the app audit](MANUAL-WORKFLOW-AUDIT.md).

Real on-device speech, full VoiceOver/accessibility, mixed/VFR/HDR coverage, full
disk/disconnected-drive behavior, M1 16 GB performance and musician/student
usability remain open. Synthetic fixtures do not close real-footage usability.
