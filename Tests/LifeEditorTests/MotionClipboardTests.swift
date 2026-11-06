import Foundation
import Testing
import LifeCore
@testable import LifeEditor

@MainActor @Test func motionKeysCopyAcrossClocksMergeAtomicallyAndUndo()throws {
    let store=EditorStore()
    let first=VisualTransform(rotationDegrees:10,cropLeft:0.1)
    let last=VisualTransform(x:0.7,rotationDegrees:90,cropRight:0.25)
    let clip=Clip(duration:.init(value:8,timescale:1),title:.init(text:"Motion"),visualAnimation:.init(keyframes:[.init(time:.zero,visual:first),.init(time:.init(value:2,timescale:1),visual:last)]))
    store.replace(ProjectDocument(sequence:.init(tracks:[.init(name:"Title",kind:.title,clips:[clip])])))
    store.selection=clip.id;store.seek(0);store.selectAllVisualKeys()
    let data=try #require(try store.encodedVisualKeys())
    let before=store.document
    store.seek(4);store.pasteVisualKeys(data:data)
    let changed=store.document
    let result=try #require(store.selectedClip)
    #expect(result.visualAnimation?.keyframes.count==4)
    #expect(result.visualTransform(at:.init(value:4,timescale:1)).rotationDegrees==10)
    #expect(result.visualTransform(at:.init(value:6,timescale:1)).cropRight==0.25)
    store.undo();#expect(store.document==before)
    store.redo();#expect(store.document==changed)
    store.seek(7);store.pasteVisualKeys(data:data)
    #expect(store.document==changed);#expect(store.error != nil)
    store.error=nil;store.seek(0);store.pasteVisualKeys(data:Data("{}".utf8))
    #expect(store.document==changed)
    store.error=nil;store.selectAllVisualKeys();store.removeSelectedVisualKeys()
    #expect(store.selectedClip?.visualAnimation==nil)
    store.undo();#expect(store.document==changed)
}
