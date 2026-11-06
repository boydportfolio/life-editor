import AppKit
import Foundation
import Testing
import LifeCore
@testable import LifeEditor

@MainActor @Test func propertyCurvesSurviveSplitRetimeReopenAndUndo()throws {
    let clip=Clip(duration:.init(value:4,timescale:1),title:.init(text:"Animate",fontSize:20),propertyAnimations:[.init(property:.titleSize,points:[.init(time:.zero,value:20),.init(time:.init(value:4,timescale:1),value:60)])])
    let original=ProjectDocument(sequence:.init(tracks:[.init(name:"Text",kind:.title,clips:[clip])]))
    let editor=ProjectEditor(document:original)
    try editor.perform(.split(clipID:clip.id,at:.init(value:1,timescale:1)))
    var right=editor.document.sequence.tracks[0].clips[1]
    #expect(right.evaluatedProperties(at:.init(value:1,timescale:1)).title?.fontSize==40)
    try editor.perform(.retime(clipID:right.id,speed:2,preservesPitch:true))
    right=editor.document.sequence.tracks[0].clips[1]
    #expect(right.evaluatedProperties(at:.init(value:1,timescale:2)).title?.fontSize==40)
    #expect(try ProjectDocument.decode(editor.document.encoded())==editor.document)
    editor.undo();editor.undo();#expect(editor.document==original)
    var invalid=original;invalid.sequence.tracks[0].clips[0].propertyAnimations?[0].points[1].value=5000
    #expect(throws:DocumentError.invalidTiming){try invalid.validate()}
    invalid=original;let duplicate=invalid.sequence.tracks[0].clips[0].propertyAnimations![0];invalid.sequence.tracks[0].clips[0].propertyAnimations?.append(duplicate)
    #expect(throws:DocumentError.invalidTiming){try invalid.validate()}
}

@MainActor @Test func propertyKeyEditingPreservesBaseAndRejectsOutOfRangeValues()throws {
    let store=EditorStore(),clip=Clip(duration:.init(value:4,timescale:1),title:.init(text:"Text",fontSize:20))
    store.replace(ProjectDocument(sequence:.init(tracks:[.init(name:"Text",kind:.title,clips:[clip])])))
    store.selection=clip.id;store.seek(2)
    let target=PropertyAnimation(property:.titleSize),before=store.document
    store.setPropertyKey(target,value:60)
    #expect(store.selectedClip?.title?.fontSize==20)
    #expect(store.selectedEvaluatedProperties?.title?.fontSize==60)
    #expect(store.selectedClip?.evaluatedProperties(at:.init(value:1,timescale:1)).title?.fontSize==40)
    let after=store.document
    store.undo();#expect(store.document==before);store.redo();#expect(store.document==after)
    store.setPropertyKey(target,value:Double.infinity);#expect(store.document==after)
    store.removePropertyAnimation(target);#expect(store.selectedClip?.propertyAnimations==nil)
    store.undo();#expect(store.document==after)
}

@Test func propertyDrawingAndEffectCurvesEvaluateAndRejectMissingTargets()throws {
    let stroke=DrawingStroke(points:[.init(x:0.1,y:0.5),.init(x:0.9,y:0.5)])
    let effect=NativeEffectRegistry.make("life.adjust.saturation")
    let clip=Clip(duration:.init(value:2,timescale:1),effects:[effect],graphic:.drawing(.init(strokes:[stroke])),propertyAnimations:[
        .init(property:.drawingWidth,points:[.init(time:.zero,value:0.01),.init(time:.init(value:2,timescale:1),value:0.05)]),
        .init(property:.effectStrength,effectID:effect.id,points:[.init(time:.zero,value:0),.init(time:.init(value:2,timescale:1),value:1)])])
    let evaluated=clip.evaluatedProperties(at:.init(value:1,timescale:1))
    if case .drawing(let drawing)=evaluated.graphic{#expect(abs(drawing.strokes[0].width-0.03)<1e-12)}else{Issue.record("Missing drawing")}
    #expect(evaluated.effects?.first?.strength==0.5)
    try ProjectDocument(sequence:.init(tracks:[.init(name:"Drawing",kind:.drawing,clips:[clip])])).validate()
    let absent=PropertyAnimation(property:.effectStrength,effectID:UUID(),points:[.init(time:.zero,value:0.5)])
    #expect(!absent.isValid(in:clip))
}

@MainActor @Test func effectRemovalAndReplacementDiscardOnlyTheirCurvesAndUndo()throws {
    let store=EditorStore(),effect=NativeEffectRegistry.make("life.adjust.saturation")
    let clip=Clip(duration:.init(value:4,timescale:1),title:.init(text:"Text"),effects:[effect],propertyAnimations:[
        .init(property:.effectStrength,effectID:effect.id,points:[.init(time:.zero,value:0.5)]),
        .init(property:.titleSize,points:[.init(time:.zero,value:40)])])
    let original=ProjectDocument(sequence:.init(tracks:[.init(name:"Text",kind:.title,clips:[clip])]))
    store.replace(original);store.selection=clip.id
    store.resetAdjustments()
    #expect(store.error==nil);#expect(store.selectedClip?.effects?.isEmpty==true)
    #expect(store.selectedClip?.propertyAnimations?.map(\.property)==[.titleSize])
    store.undo();#expect(store.document==original)
    let pasteboard=NSPasteboard(name:.init("life-property-effects-\(UUID())"))
    defer{pasteboard.releaseGlobally()}
    store.copyEffectSettings(to:pasteboard);store.pasteEffectSettings(from:pasteboard)
    #expect(store.error==nil);#expect(store.selectedClip?.effects?.first?.id != effect.id)
    #expect(store.selectedClip?.propertyAnimations?.map(\.property)==[.titleSize])
    store.undo();#expect(store.document==original)
    // Invalid unrelated mutations must still be rejected, not silently repaired.
    store.editSelected{$0.propertyAnimations?[1].points[0].value=5000}
    #expect(store.document==original);#expect(store.error != nil)
}

@MainActor @Test func detachAnimatedVideoKeepsVisualCurvesOnVideoAndSupportsUndo()throws {
    let store=EditorStore(),effect=NativeEffectRegistry.make("life.adjust.saturation")
    let asset=MediaAsset(url:URL(fileURLWithPath:"/tmp/animated-detach.mov"),kind:.video,duration:.init(value:4,timescale:1))
    let clip=Clip(assetID:asset.id,duration:asset.duration,effects:[effect],visualAnimation:.init(keyframes:[.init(time:.zero,visual:.init(x:0.2))]),propertyAnimations:[.init(property:.effectStrength,effectID:effect.id,points:[.init(time:.zero,value:0.5)])])
    let original=ProjectDocument(sequence:.init(tracks:[.init(name:"Video",kind:.video,clips:[clip])]),assets:[asset])
    store.replace(original);store.selection=clip.id;store.detachAudio()
    #expect(store.error==nil);#expect(store.document.sequence.tracks.count==2)
    let audio=try #require(store.document.sequence.tracks.last?.clips.first)
    #expect(audio.propertyAnimations==nil && audio.visualAnimation==nil && audio.effects==nil)
    #expect(store.selectedClip?.propertyAnimations==clip.propertyAnimations)
    #expect(store.selectedClip?.visualAnimation==clip.visualAnimation)
    try store.document.validate()
    store.undo();#expect(store.document==original)
}
