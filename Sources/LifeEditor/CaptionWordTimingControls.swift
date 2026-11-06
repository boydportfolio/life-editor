import SwiftUI
import LifeCore

struct CaptionWordTimingControls:View {
    @ObservedObject var store:EditorStore
    @State private var expanded=false
    var body:some View{
        let generation=store.projectGeneration
        if let clip=store.selectedClip,let title=clip.title{
            if let timing=title.wordTiming{
                DisclosureGroup("Word timing",isExpanded:$expanded){
                    VStack(spacing:10){
                        HStack{
                            SharedColorPicker(label:"Highlight",color:Binding(get:{store.selectedClip?.title?.wordTiming?.highlightColor ?? timing.highlightColor},set:{store.setWordHighlightColor($0,clipID:clip.id,generation:generation)}),store:store)
                            Button{store.clearWordTiming()}label:{Image(systemName:"trash").frame(width:24,height:24)}.help("Remove word timing").accessibilityLabel("Remove word timing")
                        }
                        LazyVStack(alignment:.leading,spacing:10){
                            ForEach(timing.words){word in
                                VStack(alignment:.leading,spacing:3){
                                    Text(word.text).font(.caption).lineLimit(2)
                                    HStack(spacing:4){
                                        WordTimingBoundaryField(store:store,word:word,start:true)
                                        Button{store.captureWordBoundary(word.id,start:true)}label:{Image(systemName:"arrow.down.to.line").frame(width:22,height:22)}.help("Set word start at playhead").accessibilityLabel("Capture word start at playhead")
                                        WordTimingBoundaryField(store:store,word:word,start:false)
                                        Button{store.captureWordBoundary(word.id,start:false)}label:{Image(systemName:"arrow.down.to.line").frame(width:22,height:22)}.help("Set word end at playhead").accessibilityLabel("Capture word end at playhead")
                                        Button{store.clearWordInterval(word.id)}label:{Image(systemName:"xmark").frame(width:22,height:22)}.help("Clear this word's interval").accessibilityLabel("Clear word interval")
                                    }
                                }.id("\(store.projectGeneration)|\(clip.id)|\(word.id)")
                            }
                        }
                    }.padding(.top,8)
                }
            }else{
                HStack{Text("Word timing");Spacer();Button{store.prepareWordTiming();expanded=true}label:{Image(systemName:"text.word.spacing").frame(width:24,height:24)}.help("Set explicit word times").accessibilityLabel("Prepare word timing")}
            }
        }
    }
}

private struct WordTimingBoundaryField:View {
    @ObservedObject var store:EditorStore
    let word:TimedTitleWord
    let start:Bool
    @State private var draft=""
    @State private var initial=""
    @State private var context:WordTimingEditContext?
    @FocusState private var focused:Bool
    var body:some View{
        TextField(start ? "Start":"End",text:$draft).textFieldStyle(.roundedBorder).frame(minWidth:42,maxWidth:62)
            .accessibilityLabel(start ? "Word start in seconds":"Word end in seconds")
            .focused($focused).onAppear{refresh()}.onSubmit{commit()}
            .onChange(of:focused){_,active in if active{refresh()}else{commit()}}
            .onChange(of:store.selectedClip?.title?.wordTiming){_,_ in if !focused{refresh()}}
    }
    private func refresh(){
        context=WordTimingEditContext(store:store)
        if let timing=store.selectedClip?.title?.wordTiming,let current=timing.words.first(where:{$0.id==word.id}),let original=start ? current.start:current.end,let local=try? timing.localTime(for:original){draft=String(format:"%.3f",local.seconds)}else{draft=""}
        initial=draft
    }
    private func commit(){
        guard draft != initial,let context else{return}
        guard context.matches(store) else{refresh();return}
        let text=draft.trimmingCharacters(in:.whitespacesAndNewlines)
        let seconds=text.isEmpty ? nil:Double(text.replacingOccurrences(of:",",with:"."))
        guard text.isEmpty || seconds != nil else{store.error="Enter seconds or leave the field empty.";refresh();return}
        store.setWordBoundary(word.id,start:start,localSeconds:seconds,context:context);refresh()
    }
}
