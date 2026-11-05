# Running-app workflow and interface audit

November 3–4, 2026, macOS 15.6 on the local M4. Native app interaction and decoded
delivery checks are tracked separately from automated test fixtures.

## Initial running-app evidence

The optimized reader-fix build imports a four-second movie with audio, splits it
at one second, undoes/redoes the split, adds a bold title, saves a `.lifeedit`
package, reopens it through Open Recent and exports H.264/AAC MP4. The saved JSON
contains both video pieces and the styled `Reader check` title. The exported file
decodes completely. The owner helped activate the initial import dialog.

Four generated eight-second camera movies and a separate 990 Hz master WAV were
also imported through the native file picker. The app selected the independent
master by default. Four video decisions and a numeric cut refinement to 1.600 s
survived save/reopen. Decoded MP4 frames at 0.5, 2, 3 and 5 seconds match the saved
camera identities. Across those same times, the master tone remains present and
the camera tones remain below the check's leakage threshold. These synthetic
media files exercise actual decoding/editing/export; they are not a real concert
or drift/synchronization usability session.

A validation agent improperly operated the app during the initial camera pass,
despite a test-only assignment. That pass is not independent switching evidence.
Its saved-package and decoded-export results remain useful; a coordinator-only
repeat is required below. Other agents must not inspect or operate the shared UI
during that repeat.

## Reproducible interface findings

- Paused camera switching could rebuild the preview and overwrite the exact
  stepped clock with a stale AVPlayer position. Periodic callbacks now own the
  clock only during playback; paused seeks/steps keep their rational position.

- Reopening from a focused numeric cut field twice raised a spurious editing
  safety alert. Numeric cut drafts now commit on submit/focus loss only against
  the same project session and unchanged cut. Replaced-session drafts cancel;
  externally changed cuts refresh the rejected draft's displayed time. Genuine
  invalid cut edits retain validation.
- Every custom timeline action/height control was reported disabled to native
  accessibility clients. Enabled state is now explicit. Clip, automation-point
  and track-edit controls remain disabled during placement previews, including
  no-op previews; navigation and layout controls retain their existing behavior.
- Saved projects continued to display `Untitled`, and suggested that name for
  export. The package filename now supplies the visible name and Save As,
  collection and movie-export defaults without rewriting stored document content.

## Practical interface observations

The actual 1280 × 800 workspace keeps the output visible beside four numbered
camera proxies. The layered timeline and separate video/audio decision lanes are
visible, and the master picker makes audio ownership explicit. Toolbar actions
are icon-based with accessible names. Numeric range entry of `1.25` did not
trigger the global camera shortcuts; the suspected shortcut collision was not
reproduced. Numeric cut refinement works without pointer dragging.

The four proxies are small, camera numbering follows imported asset order rather
than filenames, and five source tracks require vertical scrolling at the default
timeline height. These are practical usability observations to revisit with real
footage, not proof that a redesign is required. A 64-point inherited title overflowed the 320 × 180 test canvas; reducing its
size through the native slider produced a fully visible exported title. Adaptive
initial title sizing and precise numeric size entry remain usability follow-ups.
Pointer drag/trim, full keyboard
focus order and VoiceOver still need a dedicated pass.

## Updated-build acceptance

- [x] Coordinator-only camera switching, save/reopen and decoded delivery repeat.
- [x] Focused numeric cut edit followed by reopen shows no stale-edit alert.
- [x] Enabled timeline accessibility actions select the intended clip/control.
- [x] Combined movie, separate music fade, title, save/reopen and export.

The final `Life Editor Delivery.app` uses the updated source. Starting with a
fresh import, the coordinator arms paused switching and records keys 2/3/4 at
exactly 1/2/3 seconds, checks undo/redo, refines the first switch to 1.200 s and
saves/reopens `final-sources/ControlledMulticam.lifeedit` without an alert. A live
armed pass adds a displayed-frame cut, stops at the eight-second end and undoes
as one edit back to the planned decisions. The final app-exported
`ControlledMulticam.mp4` decodes completely. Frames at 0.5/1.3/2.5/5 seconds match
Camera1/Camera4/Camera3/Camera2 respectively. Each is within 20 RGB code values of
the decoded source, with an independent nearest-camera identity check. The 990 Hz
master amplitude remains approximately 3996–3998 in 16-bit units; camera-frequency
projections remain below 30 across all four windows. This is a routing check,
not lossless AAC or full color-management certification.

The combined project retains two video pieces, the styled `Reader check` title,
a separate four-second music track and 0.5 s fades. It reopens in the final build;
native timeline selection, vertical scrolling and camera-track muting work. The
final `CombinedWorkflowFinal.mp4` decodes fully, and its actual one-second frame
was visually inspected for readable title placement. Audio RMS is about 80 at
0.025 s, 1136 at 1 s and 91 at 3.95 s, confirming both fade ends. The source camera
audio is explicitly muted. The real multicam workspace image was also inspected.

Final stable-source checks pass **316 tests across 15 suites in 59.634 seconds**.
The optimized build, strict ad-hoc signature and bundled LGPL helper checks pass.
The title-size adjustment changes project data, not source code. No additional
agent operates the UI during the final pass. Native inspection still occasionally
times out after file dialogs; restoring foreground activation through Finder
recovers the connection. This limitation is not counted as a reader crash.

Local evidence is under `/tmp/life-manual-delivery-20261103`, with the earlier
four-second project/export under `/tmp/life-reader-investigation`. Temporary
artifacts are not checked-in release assets. No recreated UI image is used as
product evidence. This audit does not close fresh-user installation, full
VoiceOver/keyboard, failure-matrix, M1 performance or musician/student testing.
