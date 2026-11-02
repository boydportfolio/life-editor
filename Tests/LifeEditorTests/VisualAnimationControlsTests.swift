import Foundation
import Testing
import AppKit
import SwiftUI
import LifeCore
@testable import LifeEditor

@MainActor @Test func visualAnimationControlsCreateNavigateAndUndoExactKeyEdits()throws {
    let clip=Clip(duration:.init(value:4,timescale:1),title:.init(text:"Reframe")),store=EditorStore()
    let original=ProjectDocument(sequence:.init(tracks:[.init(name:"Title",kind:.title,clips:[clip])]))
    store.replace(original);store.selection=clip.id;store.seek(.zero)
    store.addVisualKeyframe()
    #expect(store.selectedVisualKey != nil)
    store.seek(RationalTime(value:2,timescale:1));store.addVisualKeyframe()
    let before=store.document
    store.beginGesture()
    store.setSelectedVisualTransform(.init(x:0.7,scaleX:1.2,scaleY:1.2))
    store.setSelectedVisualTransform(.init(x:0.8,scaleX:1.5,scaleY:1.5))
    store.endGesture()
    let edited=store.document
    #expect(store.selectedVisualKey?.x==0.8 && store.visibleVisualKeys.count==2)
    store.undo();#expect(store.document==before);store.redo();#expect(store.document==edited)
    store.setVisualKeyInterpolation(.hold);#expect(store.selectedVisualKey?.interpolation == .hold)
    store.selectAdjacentVisualKey(-1);#expect(store.playheadTime == .zero)
    store.selectAdjacentVisualKey(1);#expect(store.playheadTime == .init(value:2,timescale:1))
    store.seek(RationalTime(value:1,timescale:1))
    #expect(abs(store.selectedEvaluatedVisual.x-0.65)<1e-12)
    store.setSelectedVisualTransform(.init(x:0.6))
    #expect(store.visibleVisualKeys.count==3 && store.selectedVisualKey?.x==0.6)
    #expect(try ProjectDocument.decode(store.document.encoded())==store.document)
    store.clearVisualAnimation();#expect(store.selectedClip?.visualAnimation==nil && store.selectedClip?.visual?.x==0.6)
    store.undo();#expect(store.selectedClip?.visualAnimation != nil)
}

@MainActor @Test func visualAnimationControlsRespectLocksAndRemoveLastKeyWithoutJump()throws {
    let clip=Clip(duration:.init(value:2,timescale:1),title:.init(text:"Words")),store=EditorStore()
    let original=ProjectDocument(sequence:.init(tracks:[.init(name:"Title",kind:.title,clips:[clip])]))
    store.replace(original);store.selection=clip.id;store.seek(.zero);store.addVisualKeyframe()
    store.setSelectedVisualTransform(.init(x:0.75,scaleX:1.3,scaleY:1.3))
    store.removeVisualKeyframe()
    #expect(store.selectedClip?.visualAnimation==nil && store.selectedClip?.visual?.x==0.75)
    var locked=store.document;locked.sequence.tracks[0].isLocked=true
    store.replace(locked);store.addVisualKeyframe();store.clearVisualAnimation()
    #expect(store.document==locked)
    store.replace(original);store.seek(RationalTime(value:3,timescale:1));store.playheadTime = .init(value:3,timescale:1)
    store.addVisualKeyframe();#expect(store.document==original)
}

@MainActor @Test func visualAnimationControlsFitCompactInspector()throws {
    _=NSApplication.shared
    let clip=Clip(duration:.init(value:2,timescale:1),title:.init(text:"Motion")),store=EditorStore()
    store.replace(ProjectDocument(sequence:.init(tracks:[.init(name:"Title",kind:.title,clips:[clip])])))
    store.selection=clip.id;store.seek(.zero);store.addVisualKeyframe()
    let host=NSHostingView(rootView:VisualAnimationControls(store:store).frame(width:228))
    host.frame=NSRect(x:0,y:0,width:228,height:32);host.layoutSubtreeIfNeeded()
    #expect(host.fittingSize.width<=228 && host.fittingSize.height<=32)
}

@Test func visualAnimationViewerAnchorFollowsScaledAndFlippedTitlePosition(){
    let title=TitleContent(text:"Caption",style:.init(x:0.6,y:0.8))
    let position=ViewerTransformGeometry.center(title:title,visual:.init(x:0.3,y:0.4,scaleX:2,scaleY:2,flipHorizontal:true),canvas:.init(width:100,height:100),origin:.init(x:10,y:20))
    #expect(abs(position.x-20)<1e-10 && abs(position.y-120)<1e-10)
    let picture=ViewerTransformGeometry.center(title:nil,visual:.init(x:0.3,y:0.4,scaleX:2,scaleY:2),canvas:.init(width:100,height:100),origin:.init(x:10,y:20))
    #expect(picture==CGPoint(x:40,y:60))
}

@MainActor @Test func visualAnimationLeftExtensionCanAddAndEditKeysWithoutChangingOriginalCurve()throws {
    let animation=VisualAnimation(keyframes:[.init(time:.zero,visual:.init(x:0.2),interpolation:.eased),.init(time:.init(value:2,timescale:1),visual:.init(x:0.8))])
    let clip=Clip(start:.init(value:2,timescale:1),duration:.init(value:2,timescale:1),sourceStart:.init(value:2,timescale:1),title:.init(text:"Extended"),visualAnimation:animation)
    let store=EditorStore()
    store.replace(ProjectDocument(sequence:.init(tracks:[.init(name:"Title",kind:.title,clips:[clip])])))
    store.selection=clip.id
    store.apply(.trim(clipID:clip.id,start:.init(value:1,timescale:1),end:.init(value:4,timescale:1)))
    let extended=store.document,old=try #require(store.selectedClip)
    #expect(old.visualAnimation?.evaluationOffset == .init(value:-1,timescale:1))
    store.seek(RationalTime(value:1,timescale:1));store.addVisualKeyframe()
    let added=store.document,new=try #require(store.selectedClip)
    #expect(store.selectedVisualKey != nil && store.selectedVisualKey?.time == .zero)
    #expect(new.visualAnimation?.keyframes.dropFirst().map(\.id)==animation.keyframes.map(\.id))
    for local in [RationalTime(value:1,timescale:1),.init(value:3,timescale:2),.init(value:5,timescale:2)] {
        #expect(old.visualTransform(at:local)==new.visualTransform(at:local))
    }
    store.undo();#expect(store.document==extended);store.redo();#expect(store.document==added)
    store.setSelectedVisualTransform(.init(x:0.4))
    #expect(store.selectedVisualKey?.x==0.4)
    #expect(try ProjectDocument.decode(store.document.encoded())==store.document)
}
