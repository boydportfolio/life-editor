import SwiftUI

struct CanvasPresetControls:View {
    @ObservedObject var store:EditorStore
    @State private var expanded=false
    var body:some View {
        Button{expanded.toggle()}label:{Image(systemName:"aspectratio").frame(width:30,height:30)}
            .buttonStyle(.plain).help("Canvas aspect ratio").accessibilityLabel("Canvas aspect ratio")
            .accessibilityValue("\(store.document.sequence.settings.width) by \(store.document.sequence.settings.height)")
            .popover(isPresented:$expanded){
                HStack(spacing:6){
                    ForEach(ExportCanvas.allCases.filter{$0 != .project},id:\.self){preset in
                        let dimensions=preset.dimensions(shortEdge:1080)!
                        let ratio=Double(dimensions.width)/Double(dimensions.height)
                        let selected=store.document.sequence.settings.width==dimensions.width && store.document.sequence.settings.height==dimensions.height
                        Button{store.setCanvas(preset);expanded=false}label:{
                            VStack(spacing:7){
                                ZStack{
                                    Color.clear.frame(width:54,height:50)
                                    RoundedRectangle(cornerRadius:3).stroke(lineWidth:1.5)
                                        .frame(width:ratio>1 ? 50:40*ratio,height:ratio>1 ? 50/ratio:40)
                                    if selected{Image(systemName:"checkmark").font(.caption.bold())}
                                }
                                Text(preset.rawValue).font(.caption)
                            }.frame(width:66,height:80)
                                .background(selected ? Color.accentColor.opacity(0.2):.clear,in:RoundedRectangle(cornerRadius:6))
                        }.buttonStyle(.plain).help("\(preset.rawValue) canvas · \(dimensions.width) × \(dimensions.height)")
                            .accessibilityLabel("\(preset.rawValue) canvas")
                            .accessibilityValue(selected ? "Selected":"Not selected")
                    }
                }.padding(12)
            }.disabled(store.busy || store.placementProposal != nil)
    }
}
