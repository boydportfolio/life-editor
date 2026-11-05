import Foundation
import Testing
import LifeCore
@testable import LifeEditor

@MainActor private func numericCutStore()->EditorStore {
    let duration=RationalTime(value:6,timescale:1)
    let assets=(0..<2).map{MediaAsset(url:URL(fileURLWithPath:"/tmp/numeric-cut-\($0).mov"),kind:.video,duration:duration)}
    let group=MulticamGroup(angleAssetIDs:assets.map(\.id),masterAudioAssetID:assets[0].id,cuts:[.init(time:.zero,angleID:assets[0].id),.init(time:.init(value:2,timescale:1),angleID:assets[1].id),.init(time:.init(value:4,timescale:1),angleID:assets[0].id)])
    let tracks=assets.map{Track(name:"Camera",kind:.video,clips:[Clip(assetID:$0.id,duration:duration)])}
    let store=EditorStore();store.replace(ProjectDocument(sequence:Sequence(tracks:tracks,multicamGroups:[group]),assets:assets));store.checkingCameraAudio=false
    return store
}

@MainActor @Test func multicamNumericCutDraftCommitsOnceAndUndoesExactly()throws {
    let store=numericCutStore(),before=store.document,group=try #require(store.multicamGroup),cut=group.cuts[1]
    var draft=MulticamCutTimeDraft(store:store,groupID:group.id,cut:cut,audio:false)
    draft.seconds=2.5
    #expect(store.document==before)
    draft.commit(to:store)
    let after=store.document
    #expect(after.sequence.multicamGroups[0].cuts[1].time==RationalTime(value:5,timescale:2))
    #expect(after.sequence.multicamGroups[0].masterAudioAssetID==group.masterAudioAssetID)
    #expect(store.error==nil)
    // Return followed by focus loss is one edit, not a second undo entry.
    draft.commit(to:store)
    store.undo();#expect(store.document==before)
    store.redo();#expect(store.document==after)
}

@MainActor @Test func multicamNumericCutDraftCannotCommitIntoReopenedOrNewProject()throws {
    let store=numericCutStore(),saved=store.document,group=try #require(store.multicamGroup),cut=group.cuts[1]
    var old=MulticamCutTimeDraft(store:store,groupID:group.id,cut:cut,audio:false);old.seconds=2.5
    // Reopening retains every persisted ID, but starts a new editor session.
    store.projectGeneration+=1;store.checkingCameraAudio=true
    old.commit(to:store)
    #expect(store.document==saved);#expect(store.error==nil)
    store.checkingCameraAudio=false
    old.commit(to:store)
    #expect(store.document==saved);#expect(store.error==nil)
    // Even a document replacement outside the normal open path rejects the draft.
    var replacement=saved;replacement.id=UUID();store.replace(replacement)
    old.commit(to:store)
    #expect(store.document==replacement);#expect(store.error==nil)
}

@MainActor @Test func multicamNumericCutDraftCancelsWhenPreviewDisablesField()throws {
    let store=numericCutStore(),before=store.document,group=try #require(store.multicamGroup)
    var draft=MulticamCutTimeDraft(store:store,groupID:group.id,cut:group.cuts[1],audio:false);draft.seconds=2.5
    store.checkingCameraAudio=true;draft.commit(to:store)
    #expect(store.document==before);#expect(store.error==nil)
    store.checkingCameraAudio=false;draft.commit(to:store)
    #expect(store.document==before);#expect(store.error==nil)
}

@MainActor @Test func multicamNumericCutDraftRejectsExternalChangesAndPreservesValidation()throws {
    let store=numericCutStore(),group=try #require(store.multicamGroup)
    var old=MulticamCutTimeDraft(store:store,groupID:group.id,cut:group.cuts[1],audio:false);old.seconds=2.5
    store.editMulticamCut(group.cuts[1].id,audio:false,seconds:3,assetID:nil)
    let changed=store.document;old.commit(to:store)
    #expect(store.document==changed);#expect(store.error==nil)
    #expect(old.baseline==changed.sequence.multicamGroups[0].cuts[1])
    #expect(old.seconds==3)
    // Focus loss cancels the old draft and shows the current cut; another
    // callback cannot restore the rejected value or add an undo action.
    old.commit(to:store)
    #expect(store.document==changed);#expect(old.seconds==3)
    var invalid=MulticamCutTimeDraft(store:store,groupID:group.id,cut:changed.sequence.multicamGroups[0].cuts[1],audio:false);invalid.seconds=4.5
    invalid.commit(to:store)
    #expect(store.document==changed)
    #expect(store.error?.contains("between its neighbors")==true)
}
