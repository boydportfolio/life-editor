import AppKit
import Foundation
import Testing
import LifeCore
@testable import LifeEditor

private func pkt(_ value:Int64,_ scale:Int64=1)->RationalTime{.init(value:value,timescale:scale)}

@MainActor @Test func propertyKeyClipboardNormalizesRetimedClocksKeepsHiddenKeysAndUndoes()throws {
    let store=EditorStore(),target=PropertyAnimation(property:.titleSize)
    let sourceCurve=PropertyAnimation(property:.titleSize,points:[.init(time:pkt(0),value:20),.init(time:pkt(2),value:40,interpolation:.hold),.init(time:pkt(4),value:80,interpolation:.eased),.init(time:pkt(8),value:100)],evaluationOffset:pkt(1),timeScale:pkt(2))
    let source=Clip(duration:pkt(2),title:.init(text:"Copy"),propertyAnimations:[sourceCurve])
    let hiddenFirst=AutomationPoint(time:pkt(0),value:30),hiddenLast=AutomationPoint(time:pkt(12),value:120)
    let destinationCurve=PropertyAnimation(property:.titleSize,points:[hiddenFirst,hiddenLast],evaluationOffset:pkt(1),timeScale:pkt(2))
    let destination=Clip(start:pkt(4),duration:pkt(5),title:.init(text:"Paste"),propertyAnimations:[destinationCurve])
    store.replace(ProjectDocument(sequence:.init(tracks:[.init(name:"Text",kind:.title,clips:[source,destination])])))
    store.selection=source.id
    let visible=store.visiblePropertyKeys(target)
    #expect(visible.map(\.local)==[pkt(1,2),pkt(3,2)])
    let data=try #require(try store.encodedPropertyKeys(target,ids:Set(visible.map(\.point.id))))
    store.selection=destination.id;store.seek(5)
    let before=store.document
    store.pastePropertyKeys(target,data:data)
    #expect(store.error==nil)
    let pasted=try #require(store.selectedClip?.propertyAnimations?.first)
    #expect(pasted.evaluationOffset==pkt(1) && pasted.timeScale==pkt(2))
    #expect(pasted.points.first==hiddenFirst && pasted.points.last==hiddenLast)
    #expect(pasted.points.map(\.time)==[pkt(0),pkt(3),pkt(5),pkt(12)])
    #expect(pasted.points[1].interpolation == .hold && pasted.points[2].interpolation == .eased)
    #expect(!Set(pasted.points.map(\.id)).contains(visible[0].point.id))
    #expect(store.selectedClip?.evaluatedProperties(at:pkt(1)).title?.fontSize==40)
    #expect(store.selectedClip?.evaluatedProperties(at:pkt(2)).title?.fontSize==80)
    #expect(try ProjectDocument.decode(store.document.encoded())==store.document)
    let after=store.document
    store.undo();#expect(store.document==before);store.redo();#expect(store.document==after)
    store.seek(4);#expect(store.adjacentPropertyKey(target,direction:1)==pkt(1))
    store.selectAdjacentPropertyKey(target,direction:1);#expect(store.playheadTime==pkt(5))
    store.removePropertyKeys(target,ids:Set(pasted.points.map(\.id)))
    #expect(store.selectedClip?.propertyAnimations?.first?.points==[hiddenFirst,hiddenLast])
    store.undo();#expect(store.document==after)
}

@MainActor @Test func propertyKeysMapCompatibleEffectsByStableIDAndRejectOtherTargets()throws {
    let store=EditorStore(),first=NativeEffectRegistry.make("life.adjust.saturation"),second=NativeEffectRegistry.make("life.adjust.saturation"),other=NativeEffectRegistry.make("life.adjust.contrast")
    let sourceTarget=PropertyAnimation(property:.effectParameter,effectID:first.id,parameter:"value")
    let source=Clip(duration:pkt(2),title:.init(text:"Copy"),effects:[first],propertyAnimations:[.init(property:.effectParameter,effectID:first.id,parameter:"value",points:[.init(time:.zero,value:0.3),.init(time:pkt(2),value:1.4)])])
    let destination=Clip(start:pkt(3),duration:pkt(4),title:.init(text:"Paste"),effects:[second,other])
    store.replace(ProjectDocument(sequence:.init(tracks:[.init(name:"Titles",kind:.title,clips:[source,destination])])))
    store.selection=source.id
    let data=try #require(try store.encodedPropertyKeys(sourceTarget,ids:Set(store.visiblePropertyKeys(sourceTarget).map(\.point.id))))
    store.selection=destination.id;store.seek(4)
    let target=PropertyAnimation(property:.effectParameter,effectID:second.id,parameter:"value")
    store.pastePropertyKeys(target,data:data)
    #expect(store.error==nil)
    let curve=try #require(store.selectedClip?.propertyAnimations?.first)
    #expect(curve.effectID==second.id)
    #expect(curve.value(at:.zero)==1) // Preserve the target's unanimated value before the pasted range.
    #expect(curve.value(at:pkt(1))==0.3 && curve.value(at:pkt(3))==1.4)
    let before=store.document
    store.pastePropertyKeys(.init(property:.effectParameter,effectID:other.id,parameter:"value"),data:data)
    #expect(store.document==before && store.error != nil)
    store.error=nil
    store.pastePropertyKeys(.init(property:.effectStrength,effectID:second.id),data:data)
    #expect(store.document==before && store.error != nil)
}

@MainActor @Test func malformedAndOutOfRangePropertyKeysAreRejectedAtomically()throws {
    let store=EditorStore(),target=PropertyAnimation(property:.titleSize)
    let clip=Clip(duration:pkt(4),title:.init(text:"Keys"),propertyAnimations:[.init(property:.titleSize,points:[.init(time:.zero,value:20),.init(time:pkt(2),value:60)])])
    store.replace(ProjectDocument(sequence:.init(tracks:[.init(name:"Text",kind:.title,clips:[clip])])))
    store.selection=clip.id
    let data=try #require(try store.encodedPropertyKeys(target,ids:Set(store.visiblePropertyKeys(target).map(\.point.id))))
    let before=store.document
    for bad in [Data("{}".utf8),Data(repeating:0,count:1_048_577)]{
        store.pastePropertyKeys(target,data:bad);#expect(store.document==before && store.error != nil);store.error=nil
    }
    let dictionary=try #require(try JSONSerialization.jsonObject(with:data) as? [String:Any])
    for mode in 0..<5{
        var payload=dictionary
        var points=try #require(payload["points"] as? [[String:Any]])
        if mode==0{payload["version"]=2}
        if mode==1{points[1]["value"]=5000}
        if mode==2{points[1]["time"]=points[0]["time"]}
        if mode==3{points[1]["id"]=points[0]["id"]}
        if mode==4{points=Array(repeating:points[0],count:1001)}
        payload["points"]=points
        store.pastePropertyKeys(target,data:try JSONSerialization.data(withJSONObject:payload))
        #expect(store.document==before && store.error != nil);store.error=nil
    }
    store.seek(3);store.pastePropertyKeys(target,data:data)
    #expect(store.document==before && store.error != nil)
    store.error=nil
    store.seek(4);store.pastePropertyKeys(.init(property:.textAlpha),data:data)
    #expect(store.document==before && store.error != nil)
}

@MainActor @Test func propertyClipboardHonorsLockedTracksPendingPlacementAndCurveCapacity()throws {
    let store=EditorStore(),target=PropertyAnimation(property:.titleSize)
    let clip=Clip(duration:pkt(4),title:.init(text:"Keys"),propertyAnimations:[.init(property:.titleSize,points:[.init(time:.zero,value:20),.init(time:pkt(2),value:60)])])
    store.replace(ProjectDocument(sequence:.init(tracks:[.init(name:"Text",kind:.title,clips:[clip])])))
    store.selection=clip.id
    let ids=Set(store.visiblePropertyKeys(target).map(\.point.id)),data=try #require(try store.encodedPropertyKeys(target,ids:ids))
    store.toggleTrack(store.document.sequence.tracks[0].id,property:"lock")
    var before=store.document
    store.pastePropertyKeys(target,data:data);store.removePropertyKeys(target,ids:ids);store.setPropertyKey(target,value:35)
    #expect(store.document==before)
    store.toggleTrack(store.document.sequence.tracks[0].id,property:"lock")
    before=store.document
    store.placementProposal=try SpliceEditing.proposal(for:.insertCopies(clipIDs:[clip.id],at:pkt(5)),in:before)
    store.pastePropertyKeys(target,data:data);store.removePropertyKeys(target,ids:ids);store.removePropertyAnimation(target)
    #expect(store.document==before);store.placementProposal=nil
    var full=clip
    full.propertyAnimations=[.init(property:.titleSize,points:(0..<1000).map{.init(time:pkt(Int64($0),1000),value:20)})]
    store.replace(ProjectDocument(sequence:.init(tracks:[.init(name:"Full",kind:.title,clips:[full])])))
    store.selection=full.id;store.seek(1)
    before=store.document;store.pastePropertyKeys(target,data:data)
    #expect(store.document==before && store.error != nil)
}

@MainActor @Test func unsupportedEffectAnimationChoicesStayReadOnlyAndPreserveLegacyCurves()throws {
    let store=EditorStore(),effect=NativeEffectRegistry.make("life.adjust.levels")
    let legacy=PropertyAnimation(property:.effectParameter,effectID:effect.id,parameter:"black",points:[.init(time:.zero,value:0),.init(time:pkt(2),value:0.2)])
    let clip=Clip(duration:pkt(4),title:.init(text:"Legacy"),effects:[effect],propertyAnimations:[legacy])
    store.replace(ProjectDocument(sequence:.init(tracks:[.init(name:"Legacy",kind:.title,clips:[clip])])))
    store.selection=clip.id
    #expect(store.propertyAnimationChoices.contains{$0.identity==legacy.identity})
    #expect(!store.propertyAnimationChoices.contains{$0.effectID==effect.id && $0.property == .effectStrength})
    #expect(!store.supportsPropertyAnimation(legacy))
    let before=store.document
    let data=try #require(try store.encodedPropertyKeys(legacy,ids:Set(legacy.points.map(\.id))))
    store.setPropertyKey(legacy,value:0.1);store.pastePropertyKeys(legacy,data:data);store.setPropertyInterpolation(legacy,pointID:legacy.points[0].id,curve:.hold)
    #expect(store.document==before)
    #expect(try ProjectDocument.decode(store.document.encoded())==before)
}

@MainActor @Test func propertyPasteBeforeNegativeClockShiftsExistingKeysWithoutChangingTheirLocalTimes()throws {
    let store=EditorStore(),target=PropertyAnimation(property:.titleSize)
    let source=Clip(duration:pkt(1),title:.init(text:"Copy"),propertyAnimations:[.init(property:.titleSize,points:[.init(time:.zero,value:25),.init(time:pkt(1),value:45)])])
    store.replace(ProjectDocument(sequence:.init(tracks:[.init(name:"Source",kind:.title,clips:[source])])))
    store.selection=source.id
    let data=try #require(try store.encodedPropertyKeys(target,ids:Set(store.visiblePropertyKeys(target).map(\.point.id))))
    let oldFirst=AutomationPoint(time:.zero,value:65),oldLast=AutomationPoint(time:pkt(2),value:85)
    let curve=PropertyAnimation(property:.titleSize,points:[oldFirst,oldLast],evaluationOffset:pkt(-2))
    let destination=Clip(duration:pkt(4),title:.init(text:"Paste"),propertyAnimations:[curve])
    store.replace(ProjectDocument(sequence:.init(tracks:[.init(name:"Target",kind:.title,clips:[destination])])))
    store.selection=destination.id;store.seek(0)
    store.pastePropertyKeys(target,data:data)
    #expect(store.error==nil)
    let pasted=try #require(store.selectedClip?.propertyAnimations?.first)
    #expect(pasted.evaluationOffset == .zero)
    #expect(pasted.points.map(\.time)==[pkt(0),pkt(1),pkt(2),pkt(4)])
    let retainedFirst=try #require(pasted.points.first{$0.id==oldFirst.id}),retainedLast=try #require(pasted.points.first{$0.id==oldLast.id})
    #expect(try pasted.localTime(for:retainedFirst)==pkt(2))
    #expect(try pasted.localTime(for:retainedLast)==pkt(4))
    #expect(pasted.value(at:pkt(2))==65 && pasted.value(at:pkt(4))==85)
}
