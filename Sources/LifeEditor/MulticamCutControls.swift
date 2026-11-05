import SwiftUI
import LifeCore

struct MulticamCutControls:View {
    @ObservedObject var store:EditorStore
    @State private var audio=false
    @State private var expanded=false
    private var cuts:[MulticamCut]{audio ? (store.multicamGroup?.audioCuts ?? []):(store.multicamGroup?.cuts ?? [])}
    var body:some View{
        if let group=store.multicamGroup{
            DisclosureGroup("Cuts",isExpanded:$expanded){
                VStack(spacing:10){
                    Picker("Cuts",selection:$audio){Text("Video").tag(false);Text("Audio").tag(true)}.pickerStyle(.segmented)
                    LazyVStack(spacing:8){ForEach(cuts){cut in
                        HStack(spacing:6){
                            Button{store.seek(cut.time)}label:{Image(systemName:audio ? "waveform":"video")}.help("Go to cut").accessibilityLabel("Go to cut")
                            MulticamCutTimeField(store:store,groupID:group.id,cut:cut,audio:audio)
                                .id(MulticamCutTimeDraft.Context(store:store,groupID:group.id,cutID:cut.id,audio:audio))
                            Picker("Angle",selection:Binding(get:{cuts.first(where:{$0.id==cut.id})?.angleID ?? cut.angleID},set:{store.editMulticamCut(cut.id,audio:audio,seconds:nil,assetID:$0)})){
                                ForEach(store.document.assets.filter{group.angleAssetIDs.contains($0.id) || (audio && $0.id==group.masterAudioAssetID)}){asset in
                                    Text(asset.url.deletingPathExtension().lastPathComponent).tag(asset.id)
                                }
                                if audio{Text("Silence").tag(MulticamSwitching.silenceAudioID)}
                            }.labelsHidden().accessibilityLabel("Cut source")
                            Button{store.removeMulticamCut(cut.id,audio:audio)}label:{Image(systemName:"minus.circle")}.help("Delete cut").accessibilityLabel("Delete cut")
                        }
                    }}
                }.padding(.top,10).disabled(!store.canRefineMulticamCuts)
            }.padding(.top,12)
        }
    }
}

/// A numeric field owns its draft until submit or focus loss. Native field
/// teardown must never write into a project that has just replaced its source.
@MainActor struct MulticamCutTimeDraft {
    struct Context:Hashable {
        let projectID:UUID
        let generation:Int
        let groupID:UUID
        let cutID:UUID
        let audio:Bool
        @MainActor init(store:EditorStore,groupID:UUID,cutID:UUID,audio:Bool){
            projectID=store.document.id;generation=store.projectGeneration
            self.groupID=groupID;self.cutID=cutID;self.audio=audio
        }
    }
    let context:Context
    private(set) var baseline:MulticamCut
    var seconds:Double
    init(store:EditorStore,groupID:UUID,cut:MulticamCut,audio:Bool){
        context=Context(store:store,groupID:groupID,cutID:cut.id,audio:audio)
        baseline=cut;seconds=cut.time.seconds
    }
    mutating func commit(to store:EditorStore){
        guard let group=store.multicamGroup,
              context==Context(store:store,groupID:group.id,cutID:context.cutID,audio:context.audio),
              let current=(context.audio ? group.audioCuts ?? []:group.cuts).first(where:{$0.id==context.cutID}) else{return}
        guard current==baseline else{baseline=current;seconds=current.time.seconds;return}
        // Disabled fields can lose focus while a new preview is being prepared.
        // That is a cancelled draft, not a request to edit through the guard.
        guard store.canRefineMulticamCuts else{seconds=current.time.seconds;return}
        guard seconds != current.time.seconds else{return}
        store.editMulticamCut(context.cutID,audio:context.audio,seconds:seconds,assetID:nil)
        if let updated=(context.audio ? store.multicamGroup?.audioCuts:store.multicamGroup?.cuts)?.first(where:{$0.id==context.cutID}){
            baseline=updated;seconds=updated.time.seconds
        }
    }
}

@MainActor private struct MulticamCutTimeField:View {
    @ObservedObject var store:EditorStore
    let cut:MulticamCut
    let audio:Bool
    @State private var draft:MulticamCutTimeDraft
    @FocusState private var focused:Bool
    init(store:EditorStore,groupID:UUID,cut:MulticamCut,audio:Bool){
        self.store=store;self.cut=cut;self.audio=audio
        _draft=State(initialValue:MulticamCutTimeDraft(store:store,groupID:groupID,cut:cut,audio:audio))
    }
    var body:some View{
        TextField("Seconds",value:$draft.seconds,format:.number.precision(.fractionLength(3)))
            .textFieldStyle(.roundedBorder).frame(width:62).accessibilityLabel("Cut time in seconds")
            .focused($focused)
            .onSubmit{draft.commit(to:store)}
            .onChange(of:focused){_,active in
                if active{refresh()}else{draft.commit(to:store)}
            }
            .onChange(of:cut){_,_ in if !focused{refresh()}}
    }
    private func refresh(){
        guard let group=store.multicamGroup else{return}
        draft=MulticamCutTimeDraft(store:store,groupID:group.id,cut:cut,audio:audio)
    }
}
