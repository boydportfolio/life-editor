import AppKit
import Foundation
import Testing
import LifeCore
@testable import LifeEditor

@MainActor @Test func filterDropTargetsHoveredClipAndPreservesUnrelatedCurvesWithUndo()throws {
    let store=EditorStore(),old=NativeEffectRegistry.make("life.filter.cool"),adjust=NativeEffectRegistry.make("life.adjust.saturation")
    let left=Clip(duration:.init(value:2,timescale:1),title:.init(text:"Left"))
    let right=Clip(start:.init(value:3,timescale:1),duration:.init(value:2,timescale:1),title:.init(text:"Right"),effects:[old,adjust],propertyAnimations:[
        .init(property:.effectStrength,effectID:old.id,points:[.init(time:.zero,value:0.5)]),
        .init(property:.effectParameter,effectID:adjust.id,parameter:"value",points:[.init(time:.zero,value:0.5)]),
        .init(property:.titleSize,points:[.init(time:.zero,value:40)])])
    let original=ProjectDocument(sequence:.init(tracks:[.init(name:"Titles",kind:.title,clips:[left,right])]))
    store.replace(original);store.selection=left.id;store.selectedIDs=[left.id]
    let canvas=TimelineCanvas(store:store);canvas.frame=NSRect(x:0,y:0,width:1000,height:300)
    let box=canvas.rect(right,row:0),point=NSPoint(x:box.midX,y:box.midY)
    #expect(canvas.filterDropTarget("life.filter.grayscale",at:point)==right.id)
    #expect(canvas.performFilterDrop("life.filter.grayscale",at:point))
    #expect(store.selection==right.id && store.selectedIDs==[right.id])
    #expect(store.document.sequence.tracks[0].clips[0]==left)
    let changed=try #require(store.selectedClip)
    #expect(changed.effects?.map(\.stableID)==[adjust.stableID,"life.filter.grayscale"])
    #expect(changed.propertyAnimations?.count==2)
    #expect(changed.propertyAnimations?.contains{$0.effectID==old.id}==false)
    #expect(try ProjectDocument.decode(store.document.encoded())==store.document)
    let after=store.document;store.undo();#expect(store.document==original);store.redo();#expect(store.document==after)
}

@MainActor @Test func filterDropRejectsHeaderGapsAudioLockedAndPendingPlacement()throws {
    let store=EditorStore(),clip=Clip(duration:.init(value:2,timescale:1),title:.init(text:"Target"))
    let original=ProjectDocument(sequence:.init(tracks:[.init(name:"Title",kind:.title,clips:[clip])]))
    store.replace(original);store.selection=clip.id
    let canvas=TimelineCanvas(store:store);canvas.frame=NSRect(x:0,y:0,width:1000,height:300)
    let box=canvas.rect(clip,row:0),point=NSPoint(x:box.midX,y:box.midY)
    #expect(!canvas.performFilterDrop("life.filter.not-a-preset",at:point))
    #expect(!canvas.performFilterDrop("life.filter.cool",at:NSPoint(x:20,y:point.y)))
    #expect(!canvas.performFilterDrop("life.filter.cool",at:NSPoint(x:box.maxX+50,y:point.y)))
    var locked=original;locked.sequence.tracks[0].isLocked=true;store.replace(locked)
    #expect(!canvas.performFilterDrop("life.filter.cool",at:point));#expect(store.document==locked)
    store.replace(original);store.previewPlacement(.insertCopies(clipIDs:[clip.id],at:.init(value:3,timescale:1)),title:"Insert")
    #expect(store.placementProposal != nil);#expect(!store.applyFilter("life.filter.cool",to:clip.id));#expect(store.document==original)
    store.cancelPlacement()
    let asset=MediaAsset(url:URL(fileURLWithPath:"/tmp/drop-audio.wav"),kind:.audio,duration:clip.duration)
    let audio=Clip(assetID:asset.id,duration:asset.duration),doc=ProjectDocument(sequence:.init(tracks:[.init(name:"Audio",kind:.audio,clips:[audio])]),assets:[asset])
    store.replace(doc);#expect(!store.applyFilter("life.filter.cool",to:audio.id));#expect(store.document==doc)
}

@MainActor @Test func filterReplacementPreservesLegacySharedIDAdjustmentsAndFirstBinding()throws {
    for adjustmentFirst in [false,true] {
        let store=EditorStore(),filter=NativeEffectRegistry.make("life.filter.cool")
        var adjustment=NativeEffectRegistry.make("life.adjust.saturation");adjustment.id=filter.id
        let curve=PropertyAnimation(property:.effectStrength,effectID:filter.id,points:[.init(time:.zero,value:0.5)])
        let clip=Clip(duration:.init(value:2,timescale:1),title:.init(text:"Legacy"),effects:adjustmentFirst ? [adjustment,filter]:[filter,adjustment],propertyAnimations:[curve])
        let original=ProjectDocument(sequence:.init(tracks:[.init(name:"Title",kind:.title,clips:[clip])]))
        try original.validate();store.replace(original)
        #expect(store.applyFilter("life.filter.grayscale",to:clip.id))
        #expect(store.selectedClip?.effects?.first==adjustment)
        if adjustmentFirst{#expect(store.selectedClip?.propertyAnimations==[curve])}else{#expect(store.selectedClip?.propertyAnimations==nil)}
        store.undo();#expect(store.document==original)
    }
}
