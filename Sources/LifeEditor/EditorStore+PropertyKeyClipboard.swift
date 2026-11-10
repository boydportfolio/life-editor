import AppKit
import LifeCore

private struct PropertyKeyClipboard:Codable {
    var version=1
    var property:AnimatedProperty
    var effectStableID:String?
    var parameter:String?
    var points:[AutomationPoint]
}

extension EditorStore {
    static var propertyKeyPasteboardType:NSPasteboard.PasteboardType{.init("org.lifeeditor.property-keys")}
    var canEditPropertyKeys:Bool {
        placementProposal==nil && selectedClip != nil && !document.sequence.tracks.contains{$0.isLocked && $0.clips.contains{$0.id==selection}}
    }
    var selectedPropertyLocalTime:RationalTime? {
        guard let clip=selectedClip,playheadTime>=clip.start,playheadTime<=clip.end else{return nil}
        return try? playheadTime.checkedSubtracting(clip.start)
    }
    func visiblePropertyKeys(_ target:PropertyAnimation)->[(point:AutomationPoint,local:RationalTime)] {
        guard let clip=selectedClip,let curve=clip.propertyAnimations?.first(where:{$0.identity==target.identity}) else{return []}
        return curve.points.compactMap{point in
            guard let local=try? curve.localTime(for:point),local >= .zero,local<=clip.duration else{return nil}
            return (point,local)
        }
    }
    func adjacentPropertyKey(_ target:PropertyAnimation,direction:Int)->RationalTime? {
        guard let local=selectedPropertyLocalTime else{return nil}
        let keys=visiblePropertyKeys(target).map(\.local)
        return direction<0 ? keys.last(where:{$0<local}):keys.first(where:{$0>local})
    }
    func selectAdjacentPropertyKey(_ target:PropertyAnimation,direction:Int){
        guard placementProposal==nil,let clip=selectedClip,let local=adjacentPropertyKey(target,direction:direction),let time=try? clip.start.checkedAdding(local) else{return}
        seek(time)
    }
    func removePropertyKeys(_ target:PropertyAnimation,ids:Set<UUID>){
        guard canEditPropertyKeys,let original=selectedClip,var curves=original.propertyAnimations,
              let index=curves.firstIndex(where:{$0.identity==target.identity}) else{return}
        let visible=Set(visiblePropertyKeys(target).map(\.point.id)).intersection(ids)
        guard !visible.isEmpty else{return}
        curves[index].points.removeAll{visible.contains($0.id)}
        if curves[index].points.isEmpty{curves.remove(at:index)}
        editSelected{$0.propertyAnimations=curves.isEmpty ? nil:curves}
    }
    func encodedPropertyKeys(_ target:PropertyAnimation,ids:Set<UUID>)throws->Data? {
        guard let clip=selectedClip,propertyAnimationChoices.contains(where:{$0.identity==target.identity}),
              let curve=clip.propertyAnimations?.first(where:{$0.identity==target.identity}),curve.isValid(in:clip) else{return nil}
        let visible=visiblePropertyKeys(target).filter{ids.contains($0.point.id)}
        guard let first=visible.first else{return nil}
        let points=try visible.map{entry in AutomationPoint(time:try entry.local.checkedSubtracting(first.local),value:entry.point.value,interpolation:entry.point.interpolation)}
        let stableID=clip.effects?.first(where:{$0.id==target.effectID})?.stableID
        return try JSONEncoder().encode(PropertyKeyClipboard(property:target.property,effectStableID:stableID,parameter:target.parameter,points:points))
    }
    func pastePropertyKeys(_ target:PropertyAnimation,data:Data){
        guard supportsPropertyAnimation(target),canEditPropertyKeys,let original=selectedClip,let local=selectedPropertyLocalTime else{return}
        do{
            guard data.count<=1_048_576,propertyAnimationChoices.contains(where:{$0.identity==target.identity}),let range=target.range(in:original),let base=target.baseValue(in:original) else{throw DocumentError.invalidTiming}
            let payload=try JSONDecoder().decode(PropertyKeyClipboard.self,from:data)
            let stableID=original.effects?.first(where:{$0.id==target.effectID})?.stableID
            guard payload.version==1,payload.property==target.property,payload.parameter==target.parameter,payload.effectStableID==stableID,
                  !payload.points.isEmpty,payload.points.count<=1000,payload.points.first?.time == .zero,
                  Set(payload.points.map(\.id)).count==payload.points.count,
                  zip(payload.points,payload.points.dropFirst()).allSatisfy({$0.time<$1.time}),
                  payload.points.allSatisfy({$0.time >= .zero && $0.time.timescale<=1_000_000_000 && $0.time.seconds<=86400 && $0.value.isFinite && range.contains($0.value)}),
                  let last=payload.points.last,try local.checkedAdding(last.time)<=original.duration else{throw DocumentError.invalidTiming}
            var curves=original.propertyAnimations ?? []
            var curve=curves.first{$0.identity==target.identity} ?? target
            if curve.points.isEmpty,local > .zero{curve.points=[.init(time:.zero,value:base)]}
            for point in payload.points {
                let at=try local.checkedAdding(point.time)
                try curve.setKey(at:at,value:point.value)
                let clock=try curve.elapsedTime(at:at)
                guard let index=curve.points.firstIndex(where:{$0.time==clock}) else{throw DocumentError.invalidTiming}
                curve.points[index] = .init(time:clock,value:point.value,interpolation:point.interpolation)
            }
            guard curve.isValid(in:original) else{throw DocumentError.invalidTiming}
            if let index=curves.firstIndex(where:{$0.identity==target.identity}){curves[index]=curve}else{curves.append(curve)}
            editSelected{$0.propertyAnimations=curves}
        }catch{self.error="Cannot paste these property keys. Check the property, values and clip duration."}
    }
    func copyPropertyKeys(_ target:PropertyAnimation,ids:Set<UUID>,to board:NSPasteboard = .general){
        do{guard let data=try encodedPropertyKeys(target,ids:ids) else{return};board.clearContents();board.setData(data,forType:Self.propertyKeyPasteboardType)}
        catch{self.error=Self.message(error)}
    }
    func pastePropertyKeys(_ target:PropertyAnimation,from board:NSPasteboard = .general){
        guard let data=board.data(forType:Self.propertyKeyPasteboardType) else{return};pastePropertyKeys(target,data:data)
    }
}
