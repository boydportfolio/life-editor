# Native reader cancellation investigation

November 3–4, 2026. Reader stability and the core running-app navigation check
are now verified; broader release acceptance remains separate.

## Reproduction

The earlier native crashes are now reproduced with reader/job traces. The
four-camera workflow rapidly supersedes proxy preparation while synchronization
previews change. Two diagnostic variants ran the four-camera workflow and the
12-export/cancellation fixture together in fresh test processes:

| Before the fix | Result |
|---|---|
| Existing output workers | Seven passes, then SIGSEGV on run eight |
| Serialized sample pulls only | Seven passes, then SIGSEGV on run eight |

Both failing processes had only one admitted export active at the failure. The
first trace has a video sample call with no completion before native cancellation
starts on another thread. The second has reader startup with no completion before
native cancellation begins and ends. The native reports fault within reader
startup/sample processing, including `CMVideoFormatDescriptionMatchesImageBuffer`.
Serializing sample pulls alone does not serialize startup or cancellation.

This establishes a lifecycle overlap in our application. It does not establish
an undocumented AVFoundation thread-safety guarantee or identify Apple's internal
memory failure. Apple's [reader cancellation documentation](https://developer.apple.com/documentation/avfoundation/avassetreader/cancelreading())
describes stopping background reads; our implementation now coordinates all of
its own native reader operations explicitly.

## Fix

A shared `NativeReaderLifecycle` gives each reader one serial native queue for
startup, all output pulls, completion checks and native cancellation. A cancellation
flag is set immediately so queued/new work is rejected and in-flight results are
discarded. Native cancellation waits behind an active native call. An unconditional
asynchronous fence completes even if its caller's task is cancelled, before native
resources or temporary export files are released.

The export reader and standalone audio/meter/DSP/retime/freeze reader use the same
helper. Four separate exports can still progress concurrently. There is no
synchronous main-thread wait. Cancellation waits for the current native operation
to return; it does not promise to preempt a permanently stuck framework call.

## Evidence

- [x] Deterministic held-startup and held-read tests reject later work, prevent
  overlapping native cancel, discard cancelled results and fence cancelled cleanup.
- [x] Standalone-reader cancellation rejects subsequent native startup/sample reads.
- [x] Twenty consecutive original-reproducer runs pass after the fix.
- [x] Their traces cover 468 readers and 110,025 matched sample calls, with zero
  reader-operation/cancellation overlaps or unfinished native operations.
- [x] The native four-camera and 12-export fixtures preserve exported frames/audio
  and the original destination during cancellation.
- [x] Full native/helper suite: 307 tests across 15 suites pass in 54.666 seconds.
- [x] The checked-in stress harness passes an additional real one-round run.
- [x] Fresh optimized app build, strict ad-hoc signature and pinned helper checks pass.
- [x] Complete the running-app import/edit/save/reopen/export navigation check.

Trace output is opt-in through `LIFE_NATIVE_READER_TRACE=/path/to/new.jsonl`.
Records include job/reader IDs, monotonic time, thread, lifecycle events, output
kind, sample ordinal and native status. They omit original media URLs and payloads.
Writes go directly to the descriptor so a process crash retains preceding events.
Invalid/unwritable trace destinations do not change export behavior. The earlier
sample-pull-only A/B variant was diagnostic; the supported reader lifecycle always
serializes startup, pulls and cancellation.

```sh
LIFE_HELPER_DIRECTORY="$PWD/.local-helpers" scripts/stress-readers.sh 20 /tmp/life-reader-stress-build /tmp/life-reader-new-evidence
LIFE_HELPER_DIRECTORY="$PWD/.local-helpers" LIFE_RUN_MEDIA_INTEGRATION=1 scripts/test.sh --scratch-path /tmp/life-reader-diagnostic-validation --no-parallel
```

The harness refuses an existing evidence directory and stops on the first failing
round, preserving its log and trace. The fix and harness have separate commits.

## Navigation status

The owner confirms that the normal app opens and responds. Native inspection can
read the app and operate controls; a diagnostic copy built before the lifecycle fix successfully imports a PNG,
steps a frame, splits a clip, adds a title and accepts title text input. A genuine
running-app image was inspected. Pointer automation also reports
`noWindowsAvailable` in Finder, and native Save-panel input/focus remains unreliable.
The complete manual workflow is still open. No security setting was changed, and
no recreated product screenshot is used as evidence.

November 4: the [running-app audit](MANUAL-WORKFLOW-AUDIT.md) completes the core
combined workflow and an independent multicam saved/reopened delivery in the
updated optimized app. It also reproduces and fixes paused-clock, cut-field,
accessibility-enabled-state and saved-name defects. Final local validation passes
316 tests. The earlier inspection limitations above are historical evidence;
full VoiceOver, failure-matrix, real-footage usability and release gates remain open.
