import Foundation
import Testing
@testable import LifeCore

private func timedPhrase()->TitleContent{
    var timing=TitleWordTiming(text:"Go 👩‍🎤 now!")
    timing.words[0].start = .zero;timing.words[0].end = .init(value:1,timescale:1)
    timing.words[1].start = .init(value:1,timescale:1);timing.words[1].end = .init(value:2,timescale:1)
    timing.words[2].start = .init(value:2,timescale:1);timing.words[2].end = .init(value:3,timescale:1)
    return TitleContent(text:timing.sourceText,wordTiming:timing)
}
@Test func titleWordTimingUsesExactUnicodeRangesWithoutInferringIntervals()throws{
    let text="Hi, e\u{301}!\n👩‍🎤 世界",timing=TitleWordTiming(text:text)
    #expect(timing.isValid(for:text));#expect(timing.words.map(\.text)==["Hi,","e\u{301}!","👩‍🎤","世界"])
    #expect(timing.words.allSatisfy{$0.start==nil && $0.end==nil})
    for word in timing.words{
        let range=try #require(Range(NSRange(location:word.utf16Location,length:word.utf16Length),in:text))
        #expect(String(text[range])==word.text)
    }
    #expect(timing.activeWord(at:.zero,text:text)==nil)
    let title=timedPhrase(),words=try #require(title.wordTiming)
    #expect(words.activeWord(at:.init(value:1,timescale:1),text:title.text)?.text=="👩‍🎤")
    #expect(words.activeWord(at:.init(value:3,timescale:1),text:title.text)==nil)
    #expect(title.replacingText(title.text).wordTiming==title.wordTiming)
    #expect(title.replacingText("New text").wordTiming==nil)
}
@Test func titleWordTimingRejectsStaleRangesOverlapsDuplicatesAndInvalidClocks()throws{
    let title=timedPhrase(),original=try #require(title.wordTiming)
    for mode in 0..<8{
        var invalid=original
        switch mode{
        case 0:invalid.sourceText="Other"
        case 1:invalid.words[1].utf16Location+=1
        case 2:invalid.words[1].utf16Length-=1
        case 3:invalid.words[1].id=invalid.words[0].id
        case 4:invalid.words[1].start = .init(value:1,timescale:2)
        case 5:invalid.words[0].end = .zero
        case 6:invalid.timeScale = .zero
        default:invalid.highlightColor.alpha=2
        }
        #expect(!invalid.isValid(for:title.text))
        #expect(invalid.activeWord(at:.init(value:1,timescale:1),text:title.text)==nil)
    }
    var partial=original;partial.words[1].end=nil
    #expect(partial.isValid(for:title.text));#expect(partial.activeWord(at:.init(value:3,timescale:2),text:title.text)==nil)
    let tooMany=TitleWordTiming(text:Array(repeating:"word",count:501).joined(separator:" "))
    #expect(!tooMany.isValid(for:tooMany.sourceText))
}
@MainActor @Test func titleWordTimingClocksSurviveSplitTrimRetimeAndPersist()throws{
    let title=timedPhrase(),clip=Clip(duration:.init(value:4,timescale:1),title:title)
    let original=ProjectDocument(sequence:Sequence(tracks:[Track(name:"Caption",kind:.caption,clips:[clip])]))
    let editor=ProjectEditor(document:original)
    try editor.perform(.split(clipID:clip.id,at:.init(value:1,timescale:1)))
    let right=editor.document.sequence.tracks[0].clips[1]
    #expect(right.title?.wordTiming?.activeWord(at:.init(value:1,timescale:2),text:title.text)?.text=="👩‍🎤")
    editor.undo();#expect(editor.document==original)
    try editor.perform(.trim(clipID:clip.id,start:.init(value:1,timescale:1),end:.init(value:4,timescale:1)))
    try editor.perform(.retime(clipID:clip.id,speed:2,preservesPitch:true))
    let changed=editor.document.sequence.tracks[0].clips[0],timing=try #require(changed.title?.wordTiming)
    #expect(timing.timeScale==RationalTime(value:2,timescale:1))
    #expect(timing.activeWord(at:.init(value:1,timescale:4),text:title.text)?.text=="👩‍🎤")
    #expect(timing.activeWord(at:.init(value:3,timescale:4),text:title.text)?.text=="now!")
    #expect(try ProjectDocument.decode(editor.document.encoded())==editor.document)
    editor.undo();editor.undo();#expect(editor.document==original)
    let legacy=ProjectDocument(sequence:Sequence(tracks:[Track(name:"Title",kind:.title,clips:[Clip(duration:.init(value:1,timescale:1),title:.init(text:"No inferred words"))])]))
    #expect(try ProjectDocument.decode(legacy.encoded()).sequence.tracks[0].clips[0].title?.wordTiming==nil)
}
