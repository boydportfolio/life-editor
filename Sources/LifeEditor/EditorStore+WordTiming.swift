import Foundation
import LifeCore

@MainActor struct WordTimingEditContext {
    let projectID:UUID
    let generation:Int
    let clipID:UUID
    let text:String
    let timing:TitleWordTiming
    init?(store:EditorStore){
        guard let clip=store.selectedClip,let title=clip.title,let timing=title.wordTiming else{return nil}
        projectID=store.document.id;generation=store.projectGeneration;clipID=clip.id;text=title.text;self.timing=timing
    }
    func matches(_ store:EditorStore)->Bool{
        store.document.id==projectID && store.projectGeneration==generation && store.selection==clipID && store.selectedClip?.title?.text==text && store.selectedClip?.title?.wordTiming==timing
    }
}

extension EditorStore {
    func prepareWordTiming(){
        guard let title=selectedClip?.title else{return}
        let timing=TitleWordTiming(text:title.text)
        guard timing.isValid(for:title.text) else{error="Use 1–500 words for explicit word timing.";return}
        editSelected{$0.title?.wordTiming=timing}
    }
    func clearWordTiming(){editSelected{$0.title?.wordTiming=nil}}
    func setWordHighlightColor(_ color:RGBAColor,clipID:UUID,generation:Int){
        guard selection==clipID,projectGeneration==generation,let title=selectedClip?.title,var timing=title.wordTiming else{return}
        timing.highlightColor=color
        guard timing.isValid(for:title.text) else{return}
        editSelected{$0.title?.wordTiming=timing}
    }
    func setWordBoundary(_ wordID:UUID,start:Bool,localSeconds:Double?,context:WordTimingEditContext){
        guard context.matches(self) else{return}
        if let seconds=localSeconds,!seconds.isFinite || seconds<0 || seconds>86400{error="Keep word times inside the visible clip.";return}
        setWordBoundary(wordID,start:start,localTime:localSeconds.map{time($0,audio:true)},context:context)
    }
    private func setWordBoundary(_ wordID:UUID,start:Bool,localTime:RationalTime?,context:WordTimingEditContext){
        guard context.matches(self),let clip=selectedClip,var timing=clip.title?.wordTiming,let index=timing.words.firstIndex(where:{$0.id==wordID}) else{return}
        do{
            let original:RationalTime?
            if let local=localTime{
                guard local >= .zero,local<=clip.duration else{error="Keep word times inside the visible clip.";return}
                original=try timing.elapsedTime(at:local)
            }else{original=nil}
            if start{timing.words[index].start=original}else{timing.words[index].end=original}
            guard timing.isValid(for:context.text) else{error="Give each word an end after its start, without overlapping the next word.";return}
            guard timing != context.timing else{return}
            editSelected{$0.title?.wordTiming=timing}
        }catch{self.error="This word time cannot be represented."}
    }
    func captureWordBoundary(_ wordID:UUID,start:Bool){
        guard let context=WordTimingEditContext(store:self),let clip=selectedClip,let local=try? playheadTime.checkedSubtracting(clip.start) else{return}
        setWordBoundary(wordID,start:start,localTime:local,context:context)
    }
    func clearWordInterval(_ wordID:UUID){
        editSelected{clip in
            guard let index=clip.title?.wordTiming?.words.firstIndex(where:{$0.id==wordID}) else{return}
            clip.title?.wordTiming?.words[index].start=nil;clip.title?.wordTiming?.words[index].end=nil
        }
    }
}
