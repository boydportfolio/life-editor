import SwiftUI
import LifeCore

struct VisualAnimationControls:View {
    @ObservedObject var store:EditorStore
    var body:some View {
        HStack(spacing:4){
            Image(systemName:"move.3d").frame(width:20).help("Position and zoom keyframes").accessibilityLabel("Position and zoom motion")
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
                Button("Remove motion",role:.destructive){store.clearVisualAnimation()}
                    .disabled(store.selectedClip?.visualAnimation==nil)
            }label:{Image(systemName:"waveform.path").frame(width:26,height:30)}
                .menuStyle(.borderlessButton).fixedSize().help("Motion interpolation and reset").accessibilityLabel("Motion interpolation and reset")
        }.disabled(store.placementProposal != nil || store.document.sequence.tracks.contains{$0.isLocked && $0.clips.contains{$0.id==store.selection}})
    }
    private func button(_ image:String,_ title:String,disabled:Bool,action:@escaping ()->Void)->some View {
        Button(action:action){Image(systemName:image).frame(width:28,height:30)}.buttonStyle(.plain).help(title).accessibilityLabel(title).disabled(disabled)
    }
}
