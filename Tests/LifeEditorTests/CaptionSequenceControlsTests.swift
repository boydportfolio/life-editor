import Foundation
import Testing
import LifeCore
@testable import LifeEditor

@MainActor @Test func manualCaptionsReuseLaneAndCarryAppearanceWithFreshClocks()throws {
    let store=EditorStore()
    store.addManualCaption()
    let first=try #require(store.selectedClip)
    #expect(first.title?.fontSize==Double(store.document.sequence.settings.height)*0.045)
    store.applyCaptionPreset(.pill)
    store.editSelected{clip in
        clip.title?.animation = .init(kind:.typewriter,evaluationOffset:.init(value:1,timescale:1),timeScale:.init(value:2,timescale:1))
        clip.visual = .init()
    }
    let original=store.document,styled=try #require(store.selectedClip)
    store.addFollowingCaption()
    let added=try #require(store.selectedClip)
    #expect(store.document.sequence.tracks.count==1)
    #expect(added.start==first.end && added.duration==first.duration)
    #expect(added.title?.style==styled.title?.style && added.visual==styled.visual)
    #expect(added.title?.animation?.evaluationOffset == .zero)
    #expect(added.title?.animation?.timeScale == .init(value:1,timescale:1))
    #expect(added.id != first.id && added.sourceStart == .zero)
    let edited=store.document
    try edited.validate()
    #expect(try ProjectDocument.decode(edited.encoded())==edited)
    store.selectAdjacentCaption(-1)
    #expect(store.selection==first.id && store.playheadTime==first.start)
    #expect(store.document==edited)
    store.selectAdjacentCaption(1)
    #expect(store.selection==added.id && store.playheadTime==added.start)
    store.undo();#expect(store.document==original)
    store.redo();#expect(store.document==edited)
    let cues=edited.sequence.tracks[0].clips.map{CaptionCue(start:$0.start,duration:$0.duration,text:$0.title!.text)}
    #expect(try SRT.parse(SRT.encode(cues)).map(\.start)==cues.map(\.start))
}

@MainActor @Test func followingCaptionFitsGapAndRejectsOccupiedBoundary()throws {
    let first=CaptionCue(start:.zero,duration:.init(value:1,timescale:1),text:"One").clip
    let later=CaptionCue(start:.init(value:3,timescale:2),duration:.init(value:1,timescale:1),text:"Two").clip
    let store=EditorStore(),original=ProjectDocument(sequence:.init(tracks:[Track(name:"Captions",kind:.caption,clips:[later,first])]))
    store.replace(original);store.selection=first.id
    store.addFollowingCaption()
    #expect(store.selectedClip?.duration == .init(value:1,timescale:2))
    #expect(store.selectedClip?.end==later.start)
    let filled=store.document,selection=store.selection,playhead=store.playheadTime
    store.addFollowingCaption()
    #expect(store.document==filled && store.selection==selection && store.playheadTime==playhead)
    #expect(store.error != nil)
    store.undo();#expect(store.document==original)
}

@MainActor @Test func captionCreationRespectsLocksPendingPlacementAndExistingCues()throws {
    let clip=CaptionCue(start:.zero,duration:.init(value:2,timescale:1),text:"Locked").clip
    let store=EditorStore(),locked=ProjectDocument(sequence:.init(tracks:[Track(name:"Captions",kind:.caption,clips:[clip],isLocked:true)]))
    store.replace(locked);store.selection=clip.id
    store.addFollowingCaption();store.addManualCaption()
    #expect(store.document==locked && store.selection==clip.id)
    var unlocked=locked;unlocked.sequence.tracks[0].isLocked=false
    store.replace(unlocked);store.selection=clip.id
    store.previewPlacement(.insertCopies(clipIDs:[clip.id],at:clip.end),title:"Insert")
    let prior=store.document,priorSelection=store.selection
    store.addFollowingCaption()
    #expect(store.document==prior && store.selection==priorSelection)
    store.cancelPlacement()
    // Explicit insertion at an occupied playhead creates a separate lane.
    store.seek(.zero);store.addManualCaption()
    #expect(store.document.sequence.tracks.count==2)
    #expect(store.document.sequence.tracks[0].clips==[clip])
}

@MainActor @Test func automaticCaptionInsertionSkipsHiddenLanes()throws {
    let hidden=Track(name:"Hidden captions",kind:.caption,isHidden:true)
    let store=EditorStore()
    store.replace(ProjectDocument(sequence:.init(tracks:[hidden])))
    store.addManualCaption()
    #expect(store.document.sequence.tracks.count==2)
    #expect(store.document.sequence.tracks[0]==hidden)
    let selected=try #require(store.selectedCaptionTrack)
    #expect(!selected.isHidden && selected.clips.count==1)
}
