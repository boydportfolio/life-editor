import Foundation
import LifeCore

extension EditorStore {
    func canApplyFilter(_ stableID:String,to clipID:UUID)->Bool {
        guard placementProposal==nil,
              NativeEffectRegistry.definitions.contains(where:{$0.stableID==stableID}),
              let track=document.sequence.tracks.first(where:{$0.clips.contains{$0.id==clipID}}),
              !track.isLocked,track.kind != .audio,
              let clip=track.clips.first(where:{$0.id==clipID}) else{return false}
        return track.kind == .adjustment || clip.title != nil || clip.graphic != nil || document.assets.contains{$0.id==clip.assetID && $0.kind != .audio}
    }
    /// A drop changes exactly its target, independently of the current selection.
    @discardableResult func applyFilter(_ stableID:String,to clipID:UUID)->Bool {
        guard canApplyFilter(stableID,to:clipID) else{return false}
        var next=document
        for t in next.sequence.tracks.indices {
            guard let c=next.sequence.tracks[t].clips.firstIndex(where:{$0.id==clipID}) else{continue}
            var clip=next.sequence.tracks[t].clips[c]
            var seen=Set<UUID>(),removed=Set<UUID>()
            for effect in clip.effects ?? [] where seen.insert(effect.id).inserted {
                if effect.stableID.hasPrefix("life.filter."){removed.insert(effect.id)}
            }
            var effects=(clip.effects ?? []).filter{!$0.stableID.hasPrefix("life.filter.")}
            effects.append(NativeEffectRegistry.make(stableID,seed:17));clip.effects=effects
            clip.propertyAnimations?.removeAll{$0.effectID.map{removed.contains($0)} ?? false}
            if clip.propertyAnimations?.isEmpty == true{clip.propertyAnimations=nil}
            next.sequence.tracks[t].clips[c]=clip
        }
        replace(next)
        guard document==next else{return false}
        selectedIDs=[clipID];selection=clipID;selectedTransition=nil;panel = .effects
        return true
    }
}
