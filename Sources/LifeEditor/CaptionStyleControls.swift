import SwiftUI
import LifeCore
import LifeMedia

struct CaptionStyleControls:View {
    @ObservedObject var store:EditorStore
    @State private var choosing=false
    @State private var thumbnails:[CaptionPreset:CGImage]=[:]
    var body:some View {
        VStack(spacing:6) {
            HStack {
                cueButton("chevron.left","Previous caption",disabled:store.adjacentCaption(-1)==nil){store.selectAdjacentCaption(-1)}
                Spacer()
                if let index=store.orderedCaptionClips.firstIndex(where:{$0.id==store.selection}) {
                    Text("\(index+1) / \(store.orderedCaptionClips.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .accessibilityLabel("Caption \(index+1) of \(store.orderedCaptionClips.count)")
                }
                Spacer()
                cueButton("chevron.right","Next caption",disabled:store.adjacentCaption(1)==nil){store.selectAdjacentCaption(1)}
                cueButton("plus.bubble","Add caption after this cue",disabled:store.selectedCaptionTrack?.isLocked ?? true){store.addFollowingCaption()}
            }.disabled(store.placementProposal != nil)
            styles
        }
    }
    private func cueButton(_ symbol:String,_ label:String,disabled:Bool,action:@escaping ()->Void)->some View {
        Button(action:action){Image(systemName:symbol).frame(width:30,height:30)}
            .buttonStyle(.plain).help(label).accessibilityLabel(label).disabled(disabled)
    }
    private var styles:some View {
        HStack {
            Button{choosing=true}label:{Image(systemName:"captions.bubble").frame(width:30,height:30)}
                .buttonStyle(.plain).help("Caption styles").accessibilityLabel("Caption styles")
                .popover(isPresented:$choosing){
                    LazyVGrid(columns:[GridItem(.fixed(120)),GridItem(.fixed(120))],spacing:8){
                        ForEach(CaptionPreset.allCases,id:\.self){preset in
                            Button{store.applyCaptionPreset(preset);choosing=false}label:{
                                VStack(spacing:4){
                                    if let image=thumbnails[preset]{Image(nsImage:NSImage(cgImage:image,size:.zero)).resizable().scaledToFit().frame(height:45)}
                                    else{Color.clear.frame(height:45)}
                                    Text(preset.rawValue).font(.caption)
                                }.frame(maxWidth:.infinity).padding(4).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:6))
                            }.buttonStyle(.plain).help("Apply \(preset.rawValue) caption style").accessibilityLabel("Apply \(preset.rawValue) caption style")
                        }
                    }.padding(12).task{await loadThumbnails()}
                }
            Spacer()
            Button{store.matchCaptionTrackStyle()}label:{Image(systemName:"rectangle.stack").frame(width:30,height:30)}
                .buttonStyle(.plain).help("Match caption track style").accessibilityLabel("Match caption track style")
        }.disabled(store.selectedCaptionTrack?.isLocked ?? true)
    }
    private func loadThumbnails()async {
        do{for preset in CaptionPreset.allCases{try Task.checkCancellation();thumbnails[preset]=try await CaptionThumbnails.shared.image(for:preset)}}
        catch{if !Task.isCancelled{store.error=error.localizedDescription}}
    }
}
