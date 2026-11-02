import Foundation
import Testing
@testable import LifeCore

private func motionFixture()->Clip {
    let first=VisualTransform(x:0.2,y:0.3,scaleX:0.8,scaleY:0.6)
    let last=VisualTransform(x:0.8,y:0.7,scaleX:2,scaleY:1.5)
    return Clip(duration:.init(value:4,timescale:1),title:.init(text:"Motion"),visual:.init(rotationDegrees:12,cropLeft:0.1,flipHorizontal:true),visualAnimation:.init(keyframes:[.init(time:.zero,visual:first),.init(time:.init(value:4,timescale:1),visual:last)]))
}

@Test func visualAnimationInterpolatesWithoutChangingCropRotationOrFlip()throws {
    let clip=motionFixture()
    let middle=clip.visualTransform(at:.init(value:2,timescale:1))
    #expect(abs(middle.x-0.5)<1e-12 && abs(middle.scaleX-1.4)<1e-12)
    #expect(middle.cropLeft==0.1 && middle.rotationDegrees==12 && middle.flipHorizontal)
    #expect(clip.visualTransform(at:.init(value:-1,timescale:1)).x==0.2)
    #expect(clip.visualTransform(at:.init(value:5,timescale:1)).x==0.8)
    var eased=clip
    eased.visualAnimation?.keyframes[0].interpolation = .eased
    #expect(abs(eased.visualTransform(at:.init(value:1,timescale:1)).x-0.29375)<1e-12)
    eased.visualAnimation?.keyframes[0].interpolation = .hold
    #expect(eased.visualTransform(at:.init(value:399,timescale:100)).x==0.2)
    #expect(eased.visualTransform(at:.init(value:4,timescale:1)).x==0.8)
}

@MainActor @Test func visualAnimationClocksSurviveTrimSplitRetimeRollAndSplices()throws {
    var clip=motionFixture();clip.visualAnimation?.keyframes[0].interpolation = .eased
    let original=ProjectDocument(sequence:.init(tracks:[.init(name:"Title",kind:.title,clips:[clip])]))
    let split=ProjectEditor(document:original)
    try split.perform(.split(clipID:clip.id,at:.init(value:1,timescale:1)))
    let right=split.document.sequence.tracks[0].clips[1]
    #expect(right.visualTransform(at:.init(value:1,timescale:1))==clip.visualTransform(at:.init(value:2,timescale:1)))
    split.undo();#expect(split.document==original)
    let editor=ProjectEditor(document:original)
    try editor.perform(.trim(clipID:clip.id,start:.init(value:1,timescale:1),end:clip.end))
    let trimmed=editor.document
    try editor.perform(.retime(clipID:clip.id,speed:2,preservesPitch:true))
    let changed=editor.document.sequence.tracks[0].clips[0]
    #expect(changed.visualAnimation?.timeScale == .init(value:2,timescale:1))
    #expect(changed.visualTransform(at:.init(value:1,timescale:2))==clip.visualTransform(at:.init(value:2,timescale:1)))
    editor.undo();#expect(editor.document==trimmed);editor.undo();#expect(editor.document==original)
    let overwriter=ProjectEditor(document:original)
    try overwriter.perform(.overwriteCopies(clipIDs:[clip.id],at:.init(value:1,timescale:1)))
    let moved=try #require(overwriter.document.sequence.tracks[0].clips.first{$0.start == .init(value:1,timescale:1)})
    #expect(moved.visualTransform(at:.init(value:1,timescale:1))==clip.visualTransform(at:.init(value:1,timescale:1)))
}

@MainActor @Test func visualAnimationValidatesOrderingBoundsAndSchemaMigration()throws {
    let clip=motionFixture(),original=ProjectDocument(sequence:.init(tracks:[.init(name:"Title",kind:.title,clips:[motionFixture()])]))
    #expect(ProjectDocument.currentVersion==10)
    #expect(try ProjectDocument.decode(original.encoded())==original)
    var legacy=original;legacy.sequence.tracks[0].clips[0].visualAnimation=nil
    var json=try #require(JSONSerialization.jsonObject(with:legacy.encoded()) as? [String:Any]);json["version"]=9
    let migrated=try ProjectDocument.decode(JSONSerialization.data(withJSONObject:json))
    #expect(migrated.version==10 && migrated.sequence.tracks[0].clips[0].visualAnimation==nil)
    #expect(migrated.sequence.tracks[0].clips[0].visual==clip.visual)
    let editor=ProjectEditor(document:original)
    for invalidKeys in [
        [],
        [clip.visualAnimation!.keyframes[1],clip.visualAnimation!.keyframes[0]],
        [clip.visualAnimation!.keyframes[0],clip.visualAnimation!.keyframes[0]],
        [.init(time:.init(value:-1,timescale:1),visual:.init())],
        [.init(time:.zero,visual:.init(x:.nan))],
        [.init(time:.zero,visual:.init(scaleX:0))]
    ] as [[VisualKeyframe]] {
        var invalid=original;invalid.sequence.tracks[0].clips[0].visualAnimation?.keyframes=invalidKeys
        #expect(throws:DocumentError.invalidTiming){try editor.perform(.replace(invalid))}
        #expect(editor.document==original && !editor.canUndo)
    }
}

@MainActor @Test func visualAnimationFreezeHoldsEndpointAndRejectsUnboundedKeys()throws {
    let asset=MediaAsset(url:URL(fileURLWithPath:"/tmp/motion-source.mov"),kind:.video,duration:.init(value:4,timescale:1))
    var clip=motionFixture();clip.title=nil;clip.assetID=asset.id;clip.visualAnimation?.keyframes[0].interpolation = .hold
    let document=ProjectDocument(sequence:.init(tracks:[.init(name:"Video",kind:.video,clips:[clip])]),assets:[asset])
    let frozenDocument=try FreezeFrameEditing.extending(clipID:clip.id,duration:.init(value:1,timescale:1),sourceFrameTime:.init(value:119,timescale:30),in:document)
    let frozen=try #require(frozenDocument.sequence.tracks[0].clips.last)
    #expect(frozen.visualAnimation==nil && frozen.visual==clip.visualTransform(at:.init(value:119,timescale:30)))
    #expect(frozen.visual?.x==0.2) // The exclusive end key must never flash into a freeze.
    var tooMany=clip.visualAnimation!
    tooMany.keyframes=(0...VisualAnimation.maximumKeys).map{.init(time:.init(value:Int64($0),timescale:1000),visual:.init())}
    #expect(!tooMany.isValid)
    for scale in [RationalTime.zero,.init(value:-1,timescale:1),.init(value:10001,timescale:1)] {
        var invalid=clip.visualAnimation!;invalid.timeScale=scale
        #expect(!invalid.isValid)
    }
}

@MainActor @Test func visualAnimationFreezeUsesFinalProjectGridFrameForNonGridClipBounds()throws {
    for start in [RationalTime.zero,.init(value:1,timescale:100)] {
        let duration=RationalTime(value:201,timescale:100)
        let asset=MediaAsset(url:URL(fileURLWithPath:"/tmp/non-grid-motion.mov"),kind:.video,duration:duration)
        let localFinal=try RationalTime(value:2,timescale:1).checkedSubtracting(start)
        let animation=VisualAnimation(keyframes:[
            .init(time:.zero,visual:.init(x:0.2),interpolation:.hold),
            .init(time:localFinal,visual:.init(x:0.8))
        ])
        let clip=Clip(assetID:asset.id,start:start,duration:duration,visualAnimation:animation)
        let document=ProjectDocument(sequence:.init(tracks:[.init(name:"Video",kind:.video,clips:[clip])]),assets:[asset])
        let extended=try FreezeFrameEditing.extending(clipID:clip.id,duration:.init(value:1,timescale:1),sourceFrameTime:.init(value:2,timescale:1),in:document)
        let frozen=try #require(extended.sequence.tracks[0].clips.last)
        #expect(frozen.visual?.x==0.8 && frozen.visualAnimation==nil)
        #expect(frozen.visual==clip.visualTransform(at:localFinal))
    }
}
