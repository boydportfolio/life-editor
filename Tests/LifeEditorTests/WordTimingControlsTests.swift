import Foundation
import Testing
import LifeCore
@testable import LifeEditor

@MainActor private func wordTimingStore()->EditorStore{
    let store=EditorStore(),clip=Clip(start:.init(value:2,timescale:1),duration:.init(value:4,timescale:1),title:.init(text:"One 👩‍🎤 two."))
    store.replace(ProjectDocument(sequence:Sequence(tracks:[Track(name:"Caption",kind:.caption,clips:[clip])])))
    store.selection=clip.id;return store
}
@MainActor @Test func explicitWordBoundaryCapturePersistsAndUndoesWithoutGuesses()throws{
    let store=wordTimingStore(),before=store.document
    store.prepareWordTiming()
    let blank=store.document,word=try #require(store.selectedClip?.title?.wordTiming?.words.first)
    #expect(store.selectedClip?.title?.wordTiming?.words.allSatisfy{$0.start==nil && $0.end==nil}==true)
    store.seek(2.5);store.captureWordBoundary(word.id,start:true)
    #expect(store.selectedClip?.title?.wordTiming?.words[0].start==RationalTime(value:1,timescale:2))
    #expect(store.selectedClip?.title?.wordTiming?.activeWord(at:.init(value:3,timescale:4),text:"One 👩‍🎤 two.")==nil)
    store.seek(3);store.captureWordBoundary(word.id,start:false)
    let timed=store.document
    #expect(store.selectedClip?.title?.wordTiming?.activeWord(at:.init(value:3,timescale:4),text:"One 👩‍🎤 two.")?.id==word.id)
    #expect(try ProjectDocument.decode(timed.encoded())==timed)
    store.undo();#expect(store.selectedClip?.title?.wordTiming?.words[0].end==nil)
    store.undo();#expect(store.document==blank)
    store.undo();#expect(store.document==before)
}
@MainActor @Test func wordBoundaryRejectsStaleFieldAndInvalidNeighborEdit()throws{
    let store=wordTimingStore();store.prepareWordTiming()
    let context=try #require(WordTimingEditContext(store:store)),words=context.timing.words
    store.setWordBoundary(words[0].id,start:true,localSeconds:0,context:context)
    let current=store.document
    // A second callback with the old draft cannot rewrite the new interval.
    store.setWordBoundary(words[0].id,start:false,localSeconds:1,context:context)
    #expect(store.document==current)
    let fresh=try #require(WordTimingEditContext(store:store))
    store.projectGeneration+=1
    store.setWordBoundary(words[0].id,start:false,localSeconds:1,context:fresh)
    #expect(store.document==current)
    store.captureWordBoundary(words[0].id,start:false) // playhead before this clip
    #expect(store.document==current && store.error != nil)
}

@MainActor @Test func wordBoundaryCaptureKeepsExactNTSCContentClock()throws{
    let store=wordTimingStore();store.prepareWordTiming()
    let word=try #require(store.selectedClip?.title?.wordTiming?.words.first),rate=FrameRate(numerator:30000,denominator:1001)
    let local=rate.time(forFrame:1)
    store.seek(try RationalTime(value:2,timescale:1).checkedAdding(local));store.captureWordBoundary(word.id,start:true)
    #expect(store.selectedClip?.title?.wordTiming?.words[0].start==local)
}
