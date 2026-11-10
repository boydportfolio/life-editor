import Foundation
import Testing
import LifeCore
@testable import LifeEditor

@MainActor @Test func duplicatingTrackSelectsIndependentCopyAndIsOneUndo() throws {
    let store = EditorStore()
    let clip = Clip(duration: .init(value: 3, timescale: 1), title: .init(text: "Original"))
    let track = Track(name: "Titles", kind: .title, clips: [clip])
    let original = ProjectDocument(sequence: .init(tracks: [track]))
    store.replace(original)
    store.selection = clip.id
    #expect(store.canDuplicateTrack(track.id))
    #expect(store.duplicateTrack(track.id))
    let copied = store.document
    let duplicatedClip = try #require(copied.sequence.tracks[1].clips.first)
    #expect(store.selection == duplicatedClip.id && store.selectedIDs == [duplicatedClip.id])
    #expect(store.selectedTransition == nil && store.panel == .clip)
    #expect(duplicatedClip.id != clip.id)
    store.undo()
    #expect(store.document == original)
    store.redo()
    #expect(store.document == copied)
    store.selection = clip.id
    store.editSelected { $0.title?.text = "Edited source" }
    #expect(store.document.sequence.tracks[1].clips[0].title?.text == "Original")
}

@MainActor @Test func trackDuplicationRejectsLocksPlacementRecordingAndMulticamWithoutChangingDocument() throws {
    let store = EditorStore()
    let clip = Clip(duration: .init(value: 3, timescale: 1), title: .init(text: "Original"))
    let track = Track(name: "Title", kind: .title, clips: [clip])
    let original = ProjectDocument(sequence: .init(tracks: [track]))
    store.replace(original)
    store.selection = clip.id
    store.previewPlacement(.insertCopies(clipIDs: [clip.id], at: clip.end), title: "Insert")
    #expect(store.placementProposal != nil)
    #expect(!store.canDuplicateTrack(track.id) && !store.duplicateTrack(track.id))
    #expect(store.document == original)
    store.cancelPlacement()
    store.error = nil
    var locked = original
    locked.sequence.tracks[0].isLocked = true
    store.replace(locked)
    #expect(!store.canDuplicateTrack(track.id) && !store.duplicateTrack(track.id))
    #expect(store.document == locked)
    store.error = nil
    store.replace(original)
    store.switchArmed = true
    store.playing = true
    #expect(!store.canDuplicateTrack(track.id) && !store.duplicateTrack(track.id))
    #expect(store.document == original)
    store.playing = false
    store.switchArmed = false
    let camera = MediaAsset(url: URL(fileURLWithPath: "/tmp/duplicate-camera.mov"), kind: .video,
                            duration: .init(value: 3, timescale: 1))
    let cameraTrack = Track(name: "Camera", kind: .video, clips: [.init(assetID: camera.id, duration: camera.duration)])
    let multicam = ProjectDocument(sequence: .init(tracks: [cameraTrack], multicamGroups: [.init(angleAssetIDs: [camera.id])]),
                                   assets: [camera])
    store.replace(multicam)
    #expect(!store.canDuplicateTrack(cameraTrack.id))
    #expect(store.trackDuplicationUnavailableReason(cameraTrack.id) == TrackDuplicationError.multicamMember.localizedDescription)
    #expect(!store.duplicateTrack(cameraTrack.id) && store.document == multicam)
}

@MainActor @Test func duplicatingEmptyTrackClearsStaleClipSelection() {
    let store = EditorStore()
    let empty = Track(name: "Empty", kind: .audio)
    let clip = Clip(duration: .init(value: 1, timescale: 1), title: .init(text: "Text"))
    let original = ProjectDocument(sequence: .init(tracks: [empty, .init(name: "Text", kind: .title, clips: [clip])]))
    store.replace(original)
    store.selection = clip.id
    #expect(store.duplicateTrack(empty.id))
    #expect(store.document.sequence.tracks[1].clips.isEmpty)
    #expect(store.selection == nil && store.selectedIDs.isEmpty)
    store.undo()
    #expect(store.document == original)
}
