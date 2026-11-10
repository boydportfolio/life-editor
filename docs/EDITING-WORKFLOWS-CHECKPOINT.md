# Property keys, filters and track copies

November 10, 2026. This checkpoint advances remaining feature-list items 10, 12
and 13. It does not close the broad 1.0 requirements or move the `0.1.0-alpha.1`
source-preview tag.

## Property-key editing

The compact Animate controls provide previous/next navigation and a key chooser
with multi-selection, copy, paste and delete. Paste is reachable on a fresh
property with no keys. Copies normalize visible key times; pasting uses the
selected clip's original-content clock, preserving trim offsets, retiming and
interpolation. New points have fresh IDs. Hidden keys survive visible-key deletion.

The clipboard is typed, size/count bounded and applied atomically. Effect keys
match the selected target's stable effect ID and parameter rather than borrowing
another clip's effect-instance ID. Invalid values, incompatible properties,
clip-duration overflow, locked tracks and pending placements cannot partially
change the project. Unsupported effect-animation metadata now blocks new edits;
legacy saved curves remain preserved and inspectable.

## Effects browser

Filter cards can be dragged to a visual timeline clip, with an outline identifying
the target. The drop changes that clip rather than the previously selected clip.
Audio, gaps, headers, locked tracks, unknown presets and pending placements are
rejected. Click and drop use the same command path and support one-action undo.
Replacing a filter removes its own curves while preserving unrelated adjustments
and curves, including valid legacy projects with repeated effect IDs.

Favorites existed before this checkpoint. Direct star buttons and a favorites-only
view make them accessible without a context menu. Saved unknown IDs survive, and
registry order stays stable inside favorite and ordinary sections. Animate controls
are also available directly in the effects panel.

## Track duplication

Track controls and the timeline-header context menu duplicate ordinary tracks,
including empty tracks. Copies appear immediately above their source with a unique
name. Media references, timing and animation clocks remain unchanged; track/clip,
curve/key/point, drawing, word, effect, transition and marker identities are fresh.
Internal links/groups and clip-anchored markers/transitions are remapped; copies
do not remain coupled to the originals. The operation supports one-action undo.

Locked tracks, placement previews and armed playback reject duplication. Multicam
angle/master/audio-member tracks also reject it explicitly: the current media
compiler infers membership from asset IDs, so copying such a track would otherwise
silently enroll it in the group. Group-aware multicam duplication remains separate.

## Verification

Full local validation passes **366 tests across 15 suites** with native media and
pinned helpers enabled in **59.073 seconds**. The optimized app build, strict
ad-hoc signature and helper inventory/license checks pass. New native fixtures
save/reopen filter/property curves and compare decoded preview and ProRes export.
Core/editor tests cover identity isolation, legacy repeated IDs, source-clock
remapping, hidden keys, malformed clipboard data, rejection cases and undo.

A genuine running native build was inspected at the default 1280 × 800 workspace.
Direct favorite/favorites-only controls, filter application and direct Animate
access work. The key chooser exposes paste before any keys exist; two keys were
created, selected, copied, deleted and pasted at the playhead. Native track
controls create `Title Copy`, and one Command-Z removes the copy.

The inspection copy uses a separate bundle identifier/ad-hoc signature to avoid
other running editor instances. Pointer-drag automation intermittently returned
`noWindowsAvailable`; end-to-end manual dragging is not claimed. Timeline target
hit-testing, drop application and rejection paths pass native AppKit tests.
No reconstructed UI or substituted video layer is used as public product evidence.

Remaining work includes audio loop crossfades/reverse/speed ramps, broader editing
and effects cases, real on-device speech, format/failure matrices, M1 performance,
complete accessibility and musician/student usability. The broad roadmap boxes
remain open; this checkpoint does not reassess the overall planning estimate.
