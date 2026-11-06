import SwiftUI
import LifeCore

struct VisualAnimationControls:View {
    @ObservedObject var store:EditorStore
    @State private var keysExpanded=false
    var body:some View {
        VStack(spacing:6){
        HStack(spacing:4){
            Image(systemName:"move.3d").frame(width:20).help("Transform, crop and rotation keyframes").accessibilityLabel("Transform motion")
            button("backward.end","Previous motion keyframe",disabled:store.adjacentVisualKey(-1)==nil){store.selectAdjacentVisualKey(-1)}
            button(store.selectedVisualKey == nil ? "diamond":"diamond.fill","Add or update motion keyframe",disabled:store.selectedVisualLocalTime==nil){store.addVisualKeyframe()}
                .accessibilityValue(store.selectedVisualKey == nil ? "No key at playhead":"Key at playhead")
            button("forward.end","Next motion keyframe",disabled:store.adjacentVisualKey(1)==nil){store.selectAdjacentVisualKey(1)}
            button("trash","Delete motion keyframe",disabled:store.selectedVisualKey==nil){store.removeVisualKeyframe()}
            Spacer(minLength:0)
            Menu {
                ForEach([Interpolation.linear,.eased,.hold],id:\.rawValue){curve in
                    Button{store.setVisualKeyInterpolation(curve)}label:{
                        if store.selectedVisualKey?.interpolation==curve{Label(curve.rawValue.capitalized,systemImage:"checkmark")}
                        else{Text(curve.rawValue.capitalized)}
                    }.disabled(store.selectedVisualKey==nil)
                }
                Divider()
                Button("Choose keys…"){keysExpanded=true}.disabled(store.visibleVisualKeys.isEmpty)
                Button("Select visible keys"){store.selectAllVisualKeys()}.disabled(store.visibleVisualKeys.isEmpty)
                Button("Copy selected keys"){store.copyVisualKeys()}.disabled(store.selectedVisibleVisualKeys.isEmpty)
                Button("Paste keys at playhead"){store.pasteVisualKeys()}.disabled(store.selectedVisualLocalTime==nil)
                Button("Delete selected keys",role:.destructive){store.removeSelectedVisualKeys()}.disabled(store.selectedVisibleVisualKeys.isEmpty)
                Divider()
                Button("Remove motion",role:.destructive){store.clearVisualAnimation()}
                    .disabled(store.selectedClip?.visualAnimation==nil)
            }label:{Image(systemName:"waveform.path").frame(width:26,height:30)}
                .menuStyle(.borderlessButton).fixedSize().help("Motion interpolation and reset").accessibilityLabel("Motion interpolation and reset")
        }
        }.popover(isPresented:$keysExpanded){
            ScrollView{VStack(spacing:8){
                ForEach(store.visibleVisualKeys,id:\.key.id){entry in
                    HStack{
                        Button{store.toggleVisualKeySelection(entry.key.id)}label:{Image(systemName:store.selectedVisualKeyIDs.contains(entry.key.id) ? "checkmark.circle.fill":"circle")}.buttonStyle(.plain).accessibilityLabel("Select motion key at \(entry.local.seconds) seconds")
                        Button{if let clip=store.selectedClip{store.seek(clip.start+entry.local)}}label:{Text(String(format:"%.3f s",entry.local.seconds)).monospacedDigit()}.buttonStyle(.plain).accessibilityLabel("Go to motion key")
                        Spacer();Text(entry.key.interpolation.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.padding(12)}.frame(width:240,height:min(260,CGFloat(store.visibleVisualKeys.count*36+24)))
        }.disabled(store.placementProposal != nil || store.document.sequence.tracks.contains{$0.isLocked && $0.clips.contains{$0.id==store.selection}})
    }
    private func button(_ image:String,_ title:String,disabled:Bool,action:@escaping ()->Void)->some View {
        Button(action:action){Image(systemName:image).frame(width:28,height:30)}.buttonStyle(.plain).help(title).accessibilityLabel(title).disabled(disabled)
    }
}
