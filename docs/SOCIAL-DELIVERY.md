# Social delivery checkpoint

This slice continues the Phase 3 caption/social-delivery plan. It retains the
large viewer, full-width timeline, local processing and shared preview/export
renderer. It does not close Phase 3 or establish release readiness.

## Integrated behavior

- [x] Composition-aligned, preview-only safe guides.
- [x] Direct manual/SRT caption access and cue navigation.
- [x] Consecutive styled cues with gap, lock and hidden-track protection.
- [x] Project-canvas export default.
- [x] Persistence/undo/SRT and native decoded preview/export checks.
- [ ] Complete manual import/edit/save/reopen/export release smoke.
- [ ] Full keyboard/VoiceOver and user usability acceptance.

- Viewer-only Title & Action guides use 5% and 10% insets from the actual picture,
  including letterboxed and pillarboxed compositions.
- A conservative Social guide leaves extra bottom/right space. It is a
  composition aid, not a guarantee about a particular platform's interface.
- The viewfinder opens compact visual choices: Off, Title & Action, Social. The
  last visible style is remembered locally; the existing Settings startup toggle
  still determines whether guides initially appear. Guides never enter project
  serialization, undo, thumbnails or export.
- A caption toolbar icon provides Add, Import SRT and Export SRT without opening
  the media browser. The caption inspector adds previous/next and add-after icons.
- Consecutive cues reuse the selected caption track and carry its typography,
  background, transform and entrance recipe. New entrances start with fresh clocks;
  effects and automation remain individual. A following cue fits a shorter gap
  and rejects an occupied boundary. Existing cues are never shifted.
- Manual insertion reuses an available unlocked visible track where possible.
  Explicit insertion over an existing cue uses a separate lane. Locked selected
  caption tracks reject creation; rejected commands preserve selection/transport.
- Export defaults to the exact Project canvas, displaying its dimensions. Explicit
  landscape, portrait, square and 4:5 size presets remain available. A portrait
  project no longer silently opens export at 16:9.

## Acceptance boundaries

Focused tests cover guide geometry/preferences, unchanged project/undo state,
caption lane reuse, gap handling, locks, pending edits, hidden tracks, appearance,
fresh entrance clocks, persistence, SRT timing and social output sizes. The
connected native creative fixture includes a manually added gap cue, collection,
reopen and decoded preview/export comparisons during all three captions.

Manual app inspection, full keyboard/VoiceOver and 1280 × 800 validation must be
reported separately from automated tests. Word highlighting, animated reframing,
general keyframes, real on-device speech QA, user sessions and M1 performance
remain open in ROADMAP.md.

## November 1 validation

Full local native/helper run: **286 tests across 15 suites passed**. Optimized
app build, strict ad-hoc signature verification and pinned helper/license checks
passed. The camera-sync UI fixture now creates its own output directory rather
than depending on test order. Initial compilation errors in the older `.build`
cache disappeared with a clean scratch build; no SDK or toolchain change was made.

Running-native-app inspection verified direct caption entry, editing words,
consecutive same-track cues, previous-cue navigation and the social-guide picker.
A genuine app capture was inspected. A later file-picker check left Open disabled,
and subsequent inspection timed out; manual media import and the complete release
smoke are not claimed. A process sample showed the main thread waiting in its
normal event loop, not an established application deadlock. No recreated product
screenshot is published.

Commands:

```sh
LIFE_HELPER_DIRECTORY="$PWD/.local-helpers" LIFE_RUN_MEDIA_INTEGRATION=1 scripts/test.sh --scratch-path /tmp/life-social-validation --no-parallel
LIFE_BUILD_DIRECTORY=/tmp/life-social-app scripts/build-app.sh
```
