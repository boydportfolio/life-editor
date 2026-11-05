# Progress toward 1.0

Updated: 2026-11-03. Overall planning estimate: **about 65%** of the full owner
scope, with a rough **60–70% range**. This is an engineering estimate of integrated
behavior and remaining work, not a percentage of checked boxes, lines of code or
passing tests. It is not a release-readiness score.

The [requirement register](ROADMAP.md) remains authoritative. Its broad checkboxes
stay open until every part of the requirement and its acceptance evidence exists.

| Milestone | Evidence and current state | Remaining work |
|---|---|---|
| Phase 0: risky foundations | Technical gate verified locally: real layered edit, save/reopen, shared-render export, sample placement and four proxy previews. | M1 performance measurements belong to the release gate. |
| Phase 1: everyday editing | Most everyday paths implemented: layered editing, guarded placement, rational timing, waveforms/proxies, automation, project recovery and six export formats. | Complete track/document commands, broader linked editing and failure coverage, animation beyond volume/opacity, full VFR/HDR/format matrix. |
| Phase 2: music and multicam | Beat/manual grids, waveform/timecode/marker sync, reviewed clock correction, persistent master, armed switching, range replacement and direct cut refinement are integrated, with a connected four-camera native fixture. | Loops/crossfades, reverse, speed ramps, metronome and broader real-footage/performance workflow validation. |
| Phase 3: creator toolkit | Original filters/transitions, adjustment layers, tonal controls, text families/entrances, shared background geometry/borders/shadows, text alignment/spacing and layout recipes, editable drawing, RGB curves/levels/selective HSL, caption styles, color picker, position/zoom keyframes, social canvases and SRT/clean-caption delivery are integrated. | White-balance sampling, word highlighting, animated crop/rotation and other general parameter keyframes, and real on-device speech QA. |
| Phase 4: release quality | CI, optimized source builds, helper licensing, native integration tests and UI render checks are in place. | Full accessibility/keyboard audit, musician/student usability, M1 profiling/adaptive quality, failure matrix and all three demonstrated owner workflows. |

## Current phase: creator toolkit

Phase 3 continues at the owner's request, with its [delivery plan](PHASE3.md).
Phase 2's remaining work stays in the requirement register.

The [creative controls checkpoint](CREATIVE-CHECKPOINT.md) now integrates advanced
static color, editable strokes/points, reusable caption styles and a collected
styled-social export. Its scope and measured evidence are recorded separately
from full phase acceptance. This broader connected behavior moves the planning
estimate to about 65%; the estimate still excludes unpassed release gates.

## Previous delivery pass: direct cut refinement

This Phase 2 slice is integrated. The dominant viewer and quiet interface remain
requirements for every subsequent slice.

- [x] Direct video/audio multicam cut strips and boundary dragging.
- [x] Preview before committing; frame snapping, Option bypass and cancellation.
- [x] Exact one-action undo; source/lock/order/stale-document validation.
- [x] Keyboard/accessibility alternatives and native pointer-event coverage.
- [x] Saved refined cuts reproduce preview/export with uninterrupted master audio.

The full Phase 2 gate still requires the remaining music/retiming features and
broader four-camera performance validation. The synthetic workflow fixture alone
does not close that gate.

Next Phase 2 priorities: explicit audio looping with adjustable crossfades, reverse
and speed ramps, remaining musical-grid controls/metronome, and broader workflow
and performance coverage. Earlier incomplete requirements remain in the register.

Latest local verification: 307 tests across 15 suites in the full native/helper
run and the optimized ad-hoc app build pass. Hosted CI is checked separately after
publishing. See [verification](VERIFICATION.md) for dates and practical limits.

The October 27 [requirements audit](AUDIT-2026-10-27.md) records UI and safety
fixes. Timeline collapse is now remembered, multicam previews sit beside the output,
and malformed clip clipboard data is rejected atomically. The
[first public preview](PUBLIC-PREVIEW.md) targets November 1, separately from 1.0.

Latest chunk adds additive audio track solo with accessible empty-track controls,
schema 8 persistence and shared routing. A connected personal-project fixture
verifies trim/title/fades/collection/reopen/export and caught a now-fixed leading-gap
fade regression. At that earlier pass the estimate was about 60%; broad phase gates
are not closed by this fixture.

The October 28 creator slice adds installed font family/face/weight selection,
timed transparent image stickers and editable color emoji, with native export,
persistence and undo checks. Manual UI acceptance and the broader phase gates
remain open; native fixture validation now uses sequential outer test execution.


November 1: [social delivery](SOCIAL-DELIVERY.md) adds composition-safe viewer
guides, direct caption access/sequencing and project-canvas export defaults.
286 local native/helper tests and the optimized app build pass. Partial running
app interaction is verified; the complete manual media/release workflow remains
open. The overall planning estimate is unchanged; these additions do not close
broad phase gates.

The November 2 [social framing checkpoint](REFRAMING-CHECKPOINT.md) adds
position/zoom animation, persistent visual canvas choices and optional caption
burn-in. Static crop/rotation, other general parameter animation, word timing and
speech QA remain open. Each feature is kept in a focused commit; broad phase
checkboxes remain open until their complete acceptance criteria are met.

Stable-source clean verification on November 2 passes 303 tests across 15 suites,
including native media/helpers. Earlier combined test processes hit native
AVFoundation crashes; isolated fixtures and the clean complete run pass, with the
unconfirmed cause retained in the checkpoint notes. Manual release gates remain open.


November 3 reliability work pauses new features. The
[reader investigation](NATIVE-READER-INVESTIGATION.md) reproduces cancellation
lifecycle overlaps and fixes them in export and standalone readers. The original
reproducer passes 20 consecutive runs, and full native/helper checks pass 307
tests. Native navigation must be verified before resuming feature work.


November 4: the [running-app workflow and interface audit](MANUAL-WORKFLOW-AUDIT.md)
completes the combined split/title/music-fade save/reopen/export flow and an
independent multicam master-audio delivery. It fixes stale paused clock updates,
cut-field teardown edits, disabled accessibility states and saved project names.
Final native/helper validation passes 316 tests and the optimized build passes.
Full keyboard/VoiceOver, failure coverage, installation, real-footage usability
and M1 measurements remain open; no release or tag is created.
