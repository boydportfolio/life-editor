import Foundation
import LifeCore

extension EditorStore {
    var selectedVisualLocalTime:RationalTime? {
        guard let clip=selectedClip,!selectedIsAdjustment,
              document.sequence.tracks.first(where:{$0.clips.contains{$0.id==clip.id}})?.kind != .audio,
              playheadTime>=clip.start,playheadTime<=clip.end else{return nil}
        return try? playheadTime.checkedSubtracting(clip.start)
    }
    var selectedEvaluatedVisual:VisualTransform {
        guard let clip=selectedClip else{return .init()}
        let local=(try? playheadTime.checkedSubtracting(clip.start)) ?? .zero
        return clip.visualTransform(at:local)
    }
    var selectedVisualKey:VisualKeyframe? {
        guard let clip=selectedClip,let local=selectedVisualLocalTime,let animation=clip.visualAnimation,
              let clock=try? animation.elapsedTime(at:local) else{return nil}
        return animation.keyframes.first{$0.time==clock}
    }
    var visibleVisualKeys:[(key:VisualKeyframe,local:RationalTime)] {
        guard let clip=selectedClip,let animation=clip.visualAnimation else{return []}
        return animation.keyframes.compactMap{key in
            guard let local=try? animation.localTime(for:key),local >= .zero,local<=clip.duration else{return nil}
            return (key,local)
        }
    }
    func addVisualKeyframe(){
        guard let local=selectedVisualLocalTime,let original=selectedClip else{return}
        do{
            var animation=original.visualAnimation ?? .init(keyframes:[.init(time:.zero,visual:original.visual ?? .init())])
            try animation.setKey(at:local,visual:original.visualTransform(at:local))
            editSelected{$0.visualAnimation=animation}
        }catch{self.error=Self.message(error)}
    }
    func removeVisualKeyframe(){
        guard let key=selectedVisualKey,let local=selectedVisualLocalTime,let original=selectedClip,var animation=original.visualAnimation else{return}
        animation.keyframes.removeAll{$0.id==key.id}
        editSelected{clip in
            if animation.keyframes.isEmpty{clip.visual=original.visualTransform(at:local);clip.visualAnimation=nil}
            else{clip.visualAnimation=animation}
        }
    }
    func setVisualKeyInterpolation(_ curve:Interpolation){
        guard let key=selectedVisualKey else{return}
        editSelected{clip in
            guard let index=clip.visualAnimation?.keyframes.firstIndex(where:{$0.id==key.id}) else{return}
            clip.visualAnimation?.keyframes[index].interpolation=curve
        }
    }
    func adjacentVisualKey(_ direction:Int)->RationalTime? {
        guard let local=selectedVisualLocalTime else{return nil}
        let keys=visibleVisualKeys.map(\.local)
        return direction<0 ? keys.last(where:{$0<local}):keys.first(where:{$0>local})
    }
    func selectAdjacentVisualKey(_ direction:Int){
        guard placementProposal == nil,let clip=selectedClip,let local=adjacentVisualKey(direction),let time=try? clip.start.checkedAdding(local) else{return}
        seek(time)
    }
    /// Viewer and numeric position/scale edits share this one undoable path.
    /// Once keys exist, an edit at an intermediate frame inserts a key there.
    func setSelectedVisualTransform(_ value:VisualTransform){
        guard let clip=selectedClip else{return}
        if var animation=clip.visualAnimation {
            guard let local=selectedVisualLocalTime else{error="Move the playhead inside the clip to edit motion.";return}
            do{try animation.setKey(at:local,visual:value);editSelected{$0.visualAnimation=animation}}
            catch{self.error=Self.message(error)}
        }else{editSelected{$0.visual=value}}
    }
    func clearVisualAnimation(){
        let evaluated=selectedEvaluatedVisual
        editSelected{$0.visual=evaluated;$0.visualAnimation=nil}
    }
}
