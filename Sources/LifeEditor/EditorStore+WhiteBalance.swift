import AVFoundation
import ImageIO
import LifeCore

@MainActor struct WhiteBalanceSamplingContext {
    let document:ProjectDocument
    let generation:Int
    let selection:UUID
    let selectedIDs:Set<UUID>
    let playhead:RationalTime
    let item:AVPlayerItem?
    init(store:EditorStore,clip:Clip){
        document=store.document;generation=store.projectGeneration;selection=clip.id
        selectedIDs=store.selectedIDs;playhead=store.playheadTime;item=store.player.currentItem
    }
    func matches(_ store:EditorStore)->Bool{
        store.document==document && store.projectGeneration==generation && store.selection==selection && store.selectedIDs==selectedIDs && store.playheadTime==playhead && store.player.currentItem === item && !store.playing && !store.preparing && !store.syncPreviewing && store.placementProposal==nil && !store.switchArmed
    }
}

extension EditorStore {
    /// The viewer is composited over black. Restrict neutral picking to a single
    /// opaque source, so another layer or alpha cannot supply the sampled color.
    private var whiteBalanceSource:MediaAsset? {
        guard !preparing,!syncPreviewing,placementProposal==nil,!switchArmed,
              document.sequence.multicamGroups.isEmpty,(document.sequence.transitions ?? []).isEmpty,
              selectedIDs.count<=1,let clip=selectedClip,clip.start<=playheadTime,playheadTime<clip.end,
              clip.opacity.value(at:playheadTime-clip.start)==1,
              let asset=document.assets.first(where:{$0.id==clip.assetID && ($0.kind == .video || $0.kind == .image)}) else{return nil}
        let visible=document.sequence.tracks.filter{!$0.isHidden && $0.kind != .audio}
        guard !visible.contains(where:{$0.isLocked && $0.clips.contains(where:{$0.id==clip.id})}) else{return nil}
        let active=visible.flatMap(\.clips).filter{$0.start<=playheadTime && playheadTime<$0.end}
        guard active.count==1,active[0].id==clip.id else{return nil}
        let enabled=(clip.effects ?? []).filter(\.isEnabled)
        if let balance=enabled.firstIndex(where:{$0.stableID==WhiteBalance.stableID}),balance != enabled.count-1{return nil}
        return asset
    }
    func beginWhiteBalanceSampling(){
        stopPlayback()
        guard let asset=whiteBalanceSource,let clip=selectedClip else{error="Select one visible opaque photo or video. Remove overlays and reset white balance after later adjustments.";return}
        let context=WhiteBalanceSamplingContext(store:self,clip:clip)
        beginColorSampling{[weak self] sample in
            Task{@MainActor [weak self] in
                guard let self,context.matches(self) else{return}
                do{
                    let opaque=try await Self.whiteBalanceSourceIsOpaque(asset)
                    self.applyWhiteBalanceSample(sample,context:context,sourceIsOpaque:opaque)
                }catch{if context.matches(self){self.error="This source cannot be sampled for white balance."}}
            }
        }
    }
    func applyWhiteBalanceSample(_ sample:RGBAColor,context:WhiteBalanceSamplingContext,sourceIsOpaque:Bool){
        guard context.matches(self),whiteBalanceSource != nil,let clip=selectedClip else{return}
        guard sourceIsOpaque else{error="Use an opaque photo or video for white balance.";return}
        let balance=clip.effects?.last(where:{$0.stableID==WhiteBalance.stableID && $0.isEnabled}) ?? clip.effects?.last(where:{$0.stableID==WhiteBalance.stableID})
        guard let parameters=WhiteBalance.parameters(neutral:sample,correcting:balance) else{error="Pick a brighter neutral gray area with a moderate color cast.";return}
        editSelected{clip in
            var effects=clip.effects ?? []
            if let balance,let index=effects.firstIndex(where:{$0.id==balance.id}){
                effects[index].parameters=parameters;effects[index].strength=1;effects[index].isEnabled=true
                if !balance.isEnabled{let updated=effects.remove(at:index);effects.append(updated)}
            }else{effects.append(EffectInstance(stableID:WhiteBalance.stableID,parameters:parameters))}
            clip.effects=effects
        }
    }
    func resetWhiteBalance(){editSelected{$0.effects?.removeAll{$0.stableID==WhiteBalance.stableID}}}
    nonisolated static func whiteBalanceSourceIsOpaque(_ asset:MediaAsset)async throws->Bool{
        let url=asset.preparedURL ?? asset.url
        guard url.isFileURL else{return false}
        if asset.kind == .image {
            guard let source=CGImageSourceCreateWithURL(url as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,[kCGImageSourceShouldCache:false] as CFDictionary) else{return false}
            return [.none,.noneSkipFirst,.noneSkipLast].contains(image.alphaInfo)
        }
        let source=AVURLAsset(url:url)
        guard !(try await source.loadTracks(withMediaType:.video)).isEmpty else{return false}
        return try await source.loadTracks(withMediaCharacteristic:.containsAlphaChannel).isEmpty
    }
}
