import SwiftUI

/// Direct caption entry without opening the media browser.
struct CaptionActions:View {
    @ObservedObject var store:EditorStore
    @State private var expanded=false
    var body:some View {
        Button{expanded.toggle()}label:{Image(systemName:"captions.bubble").frame(width:30,height:30)}
            .buttonStyle(.plain).help("Captions").accessibilityLabel("Captions")
            .popover(isPresented:$expanded){
                VStack(alignment:.leading,spacing:8){
                    action("plus.bubble","Add caption",store.addManualCaption)
                    action("square.and.arrow.down","Import SRT…",store.importCaptions)
                    action("square.and.arrow.up","Export SRT…",store.exportCaptions)
                        .disabled(!store.document.sequence.tracks.contains{$0.kind == .caption && !$0.clips.isEmpty})
                }.padding(12)
            }.disabled(store.placementProposal != nil)
    }
    private func action(_ symbol:String,_ title:String,_ perform:@escaping ()->Void)->some View {
        Button{expanded=false;perform()}label:{Label(title,systemImage:symbol).frame(maxWidth:.infinity,alignment:.leading).padding(5)}
            .buttonStyle(.plain).accessibilityLabel(title)
    }
}
