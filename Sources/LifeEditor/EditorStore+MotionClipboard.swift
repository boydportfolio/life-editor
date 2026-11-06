import AppKit
import LifeCore

private struct MotionClipboard:Codable {
    var version=1
    var keys:[VisualKeyframe]
}

extension EditorStore {
    private static let motionPasteboardType=NSPasteboard.PasteboardType("org.lifeeditor.motion-keys")
    var selectedVisibleVisualKeys:[(key:VisualKeyframe,local:RationalTime)] {
        visibleVisualKeys.filter{selectedVisualKeyIDs.contains($0.key.id)}
    }
    func toggleVisualKeySelection(_ id:UUID){
        guard visibleVisualKeys.contains(where:{$0.key.id==id}) else{return}
        if selectedVisualKeyIDs.contains(id){selectedVisualKeyIDs.remove(id)}else{selectedVisualKeyIDs.insert(id)}
    }
    func selectAllVisualKeys(){selectedVisualKeyIDs=Set(visibleVisualKeys.map(\.key.id))}
    func removeSelectedVisualKeys(){
        guard let original=selectedClip,let local=selectedVisualLocalTime,var animation=original.visualAnimation else{return}
        let ids=Set(selectedVisibleVisualKeys.map(\.key.id));guard !ids.isEmpty else{return}
        animation.keyframes.removeAll{ids.contains($0.id)}
        editSelected{clip in
            if animation.keyframes.isEmpty{clip.visual=original.visualTransform(at:local);clip.visualAnimation=nil}
            else{clip.visualAnimation=animation}
        }
        selectedVisualKeyIDs=[]
    }
    func encodedVisualKeys()throws->Data? {
        guard let clip=selectedClip,let first=selectedVisibleVisualKeys.first else{return nil}
        let keys=try selectedVisibleVisualKeys.map{entry in
            VisualKeyframe(time:try entry.local.checkedSubtracting(first.local),visual:clip.visualTransform(at:entry.local),interpolation:entry.key.interpolation)
        }
        return try JSONEncoder().encode(MotionClipboard(keys:keys))
    }
    func pasteVisualKeys(data:Data){
        guard placementProposal==nil,let original=selectedClip,let local=selectedVisualLocalTime else{return}
        do{
            guard data.count<=1_048_576 else{throw DocumentError.invalidTiming}
            let payload=try JSONDecoder().decode(MotionClipboard.self,from:data)
            let copied=VisualAnimation(keyframes:payload.keys)
            guard payload.version==1,copied.isValid,payload.keys.first?.time == .zero,
                  let last=payload.keys.last,try local.checkedAdding(last.time)<=original.duration else{throw DocumentError.invalidTiming}
            var animation=original.visualAnimation ?? VisualAnimation(keyframes:[])
            for key in payload.keys {
                let at=try local.checkedAdding(key.time)
                let visual=copied.transform(at:key.time,base:.init())
                try animation.setKey(at:at,visual:visual)
                let clock=try animation.elapsedTime(at:at)
                if let index=animation.keyframes.firstIndex(where:{$0.time==clock}){animation.keyframes[index].interpolation=key.interpolation}
            }
            guard animation.isValid else{throw DocumentError.invalidTiming}
            editSelected{$0.visualAnimation=animation}
        }catch{self.error="Cannot paste motion keys here. Check the selection and clip duration."}
    }
    func copyVisualKeys(){
        do{guard let data=try encodedVisualKeys() else{return};let board=NSPasteboard.general;board.clearContents();board.setData(data,forType:Self.motionPasteboardType)}
        catch{self.error=Self.message(error)}
    }
    func pasteVisualKeys(){guard let data=NSPasteboard.general.data(forType:Self.motionPasteboardType) else{return};pasteVisualKeys(data:data)}
}
