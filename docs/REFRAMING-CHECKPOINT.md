# Social framing and delivery checkpoint

This continues Phase 3's social-video workflow, following the earlier
[safe-guide and caption checkpoint](SOCIAL-DELIVERY.md). The controls remain
local, icon-led and contextual; preview and export share the rendering path.

## Scope

- [x] Position and independent X/Y zoom keyframes with linear, eased and hold segments.
- [x] Compact add/update, delete, previous/next and interpolation controls.
- [x] Viewer manipulation and numeric transform edits evaluate the current pose;
  edits insert/update a key once motion is enabled. Static clips stay static.
- [x] Rational animation clocks survive trim, split, retime, roll and timeline splices.
- [x] Source-boundary freeze holds the last visible pose rather than an unseen endpoint.
- [x] Explicit portrait, landscape, square and 4:5 project canvases, with visual choices.
- [x] Canvas choice persists and survives first-video import; source frame rate remains independent.
- [x] Optional caption burn-in for video exports, default on; clean video retains
  ordinary titles, duration and range coordinates. SRT and saved tracks are unchanged.
- [x] Schema 10, legacy migration, undo and collected project persistence.
- [ ] Animated crop, rotation and other general parameter keyframes.
- [ ] Timed word highlighting and real on-device speech QA.
- [ ] Complete manual release smoke, keyboard/VoiceOver audit, usability sessions and M1 profiling.

## Editing behavior

Enable motion with the diamond at the playhead. Seek to another frame and move
or resize the object in the viewer, or change X/Y/Scale in Clip controls. A key
is inserted there; the original start pose is retained. Previous/next buttons
navigate visible keys. The curve control sets the outgoing segment. Deleting
the last key or removing motion holds the current pose. Crop, rotation and flips
remain static across the clip.

The canvas icon beside viewer guides changes the project frame before export.
The four choices use a 1080-pixel short edge. Choosing a canvas preserves existing
clip content, typography, transforms and timing; it does not automatically crop
or move subjects. Use Fit/Fill, direct transforms and motion keys to frame them.
The selection is undoable and protected from replacement by first-video import.

The export sheet shows Burn in captions when caption tracks exist. Turn it off
for a clean picture and export SRT from the caption toolbar icon. This is an
explicit delivery choice; the normal editing preview still shows visible caption
tracks. Hidden captions remain hidden when burn-in is enabled. Other title and
sticker tracks are unaffected.

## Compatibility and limits

Schema 10 protects position/zoom animation and explicit canvas intent. Versions
1–9 migrate without adding motion or changing their pictures. Older applications
must refuse schema 10 rather than silently omit motion. Keyframes are bounded,
ordered and validated; unsupported/future packages remain protected.

Motion is per clip, not automatic subject tracking. Static crop/rotation/flip,
word timing, full timeline keyframe multi-selection/copy/paste and other animated
parameters remain separate requirements. This checkpoint does not close the
broad creative-toolkit or release gates, and does not change the overall planning
estimate into a release-readiness score.

## Validation notes

Focused acceptance covers interpolation and malformed keys, exact undo, legacy
migration, left extensions, split/trim/retime/splice clocks, freeze endpoints and
non-grid clip bounds, scaled title viewer anchors, and compact inspector layout.
Native fixtures collect/reopen an animated image/title/shape project and compare
preview with decoded ProRes export. Separate fixtures verify actual portrait
1080 × 1920 delivery and clean/captioned video with unchanged range timing.

During combined validation, two test processes crashed inside AVFoundation's
native reader (`startReading` and `copyNextSampleBuffer`). The four-camera and
12-export stress fixtures passed in isolation. No production ownership fix is
claimed from those reports; a stable-source clean build is checked separately.
This remains evidence to retain in release QA, rather than treating a successful
isolated run as proof that the crash is resolved.

The stable-source clean native/helper run passed **303 tests across 15 suites**
on November 2, including both the four-camera and concurrent-export fixtures.
The earlier crashes did not reproduce in that clean run; their cause remains
unconfirmed. The source checks above are not a manual release acceptance pass.

```sh
LIFE_HELPER_DIRECTORY="$PWD/.local-helpers" LIFE_RUN_MEDIA_INTEGRATION=1 scripts/test.sh --scratch-path /tmp/life-framing-final --no-parallel
LIFE_BUILD_DIRECTORY=/tmp/life-framing-final-app scripts/build-app.sh
```

The clean optimized application build also passes strict ad-hoc signature and
pinned LGPL helper/inventory checks. These are local M4 measurements; they do not
establish signing/notarization, M1 performance or manual usability acceptance.


November 3 follow-up: the [reader investigation](NATIVE-READER-INVESTIGATION.md)
reproduces the previous failures during overlapping native cancellation/startup
or sample reads. The shared lifecycle fix passes the original repeated workload
and the full 307-test native/helper suite. Running-app navigation is tracked
separately and remains a prerequisite to further feature work.
