import Foundation
import LifeCore

extension EditorStore {
    var selectedCaptionTrack:Track? {
        document.sequence.tracks.first{$0.kind == .caption && $0.clips.contains{$0.id==selection}}
    }
    var orderedCaptionClips:[Clip] {
        (selectedCaptionTrack?.clips ?? []).filter{$0.title != nil}.sorted{
            if $0.start == $1.start{return $0.id.uuidString < $1.id.uuidString}
            return $0.start < $1.start
        }
    }
    func adjacentCaption(_ direction:Int)->Clip? {
        let clips=orderedCaptionClips
        guard let index=clips.firstIndex(where:{$0.id==selection}) else{return nil}
        let target=index+(direction < 0 ? -1:1)
        return clips.indices.contains(target) ? clips[target]:nil
    }
    func selectAdjacentCaption(_ direction:Int){
        guard placementProposal == nil,let clip=adjacentCaption(direction) else{return}
        selection=clip.id;seek(clip.start);panel = .title
    }
    func addFollowingCaption(){
        guard let clip=selectedClip,selectedCaptionTrack != nil else{return}
        insertManualCaption(at:clip.end,following:true)
    }
    /// Reuse a caption lane when possible. A following cue fits the available gap
    /// rather than overlapping the next cue or moving existing words.
    func insertManualCaption(at start:RationalTime,following:Bool=false){
        guard start >= .zero else{return}
        let preferred=selectedCaptionTrack
        if preferred?.isLocked == true{error="Unlock the track to edit.";return}
        var next=document
        var duration=RationalTime(value:2,timescale:1)
        if following,let preferred {
            if preferred.clips.contains(where:{$0.start <= start && start < $0.end}){
                error="There is already a caption here.";return
            }
            if let boundary=preferred.clips.filter({$0.start>start}).map(\.start).min(){
                guard let gap=try? boundary.checkedSubtracting(start),gap >= document.sequence.settings.frameRate.frameDuration else{
                    error="There is no room for another caption here.";return
                }
                duration=min(duration,gap)
            }
        }
        var clip=CaptionCue(start:start,duration:duration,text:"Caption").clip
        // Appearance carries across cues; trimmed/retimed animation clocks,
        // effects and automation belong to the original cue.
        if let original=selectedClip,preferred != nil,let title=original.title {
            clip.title?.fontSize=title.fontSize;clip.title?.style=title.style
            if let animation=title.animation {
                clip.title?.animation=TitleAnimation(kind:animation.kind,duration:animation.duration,direction:animation.direction)
            }
            clip.visual=original.visual
        }else{
            do{clip=try CaptionPreset.plain.applying(to:clip,canvasHeight:document.sequence.settings.height)}
            catch{self.error=Self.message(error);return}
        }
        let available:(Track)->Bool={track in
            track.kind == .caption && !track.isLocked && track.clips.allSatisfy{$0.end<=clip.start || clip.end<=$0.start}
        }
        let index=preferred.flatMap{track in next.sequence.tracks.firstIndex(where:{$0.id==track.id && available($0)})}
            ?? next.sequence.tracks.firstIndex(where:{!$0.isHidden && available($0)})
        if let index{next.sequence.tracks[index].clips.append(clip)}
        else{next.sequence.tracks.append(Track(name:"Captions",kind:.caption,clips:[clip]))}
        replace(next)
        // A rejected command (placement preview/recording/validation) must not
        // change the current selection or transport.
        guard document.sequence.tracks.contains(where:{$0.clips.contains(where:{$0.id==clip.id})}) else{return}
        selection=clip.id;panel = .title;seek(start)
    }
    func applyCaptionPreset(_ preset:CaptionPreset){
        guard selectedCaptionTrack != nil,let clip=selectedClip else{return}
        do{let styled=try preset.applying(to:clip,canvasHeight:document.sequence.settings.height);editSelected{$0=styled}}
        catch{self.error=Self.message(error)}
    }
    /// Match appearance only. Words, cue times, entrance clocks, effects and
    /// envelopes remain individual; the entire track change undoes once.
    func matchCaptionTrackStyle(){
        guard let track=selectedCaptionTrack,let title=selectedClip?.title else{return}
        guard !track.isLocked else{error="Unlock the track to edit.";return}
        var next=document
        guard let index=next.sequence.tracks.firstIndex(where:{$0.id==track.id}) else{return}
        for clip in next.sequence.tracks[index].clips.indices where next.sequence.tracks[index].clips[clip].title != nil {
            next.sequence.tracks[index].clips[clip].title?.style=title.style
            next.sequence.tracks[index].clips[clip].title?.fontSize=title.fontSize
        }
        replace(next)
    }
}
