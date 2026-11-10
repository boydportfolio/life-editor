import Foundation
import LifeCore

extension EditorStore {
    var selectedEvaluatedProperties:Clip? {
        guard let clip=selectedClip else{return nil}
        return clip.evaluatedProperties(at:max(.zero,min(clip.duration,playheadTime-clip.start)))
    }
    var propertyAnimationChoices:[PropertyAnimation] {
        guard let clip=selectedClip else{return []}
        var choices=AnimatedProperty.allCases.filter{$0 != .effectParameter && $0 != .effectStrength}.map{PropertyAnimation(property:$0)}.filter{$0.range(in:clip) != nil && $0.baseValue(in:clip) != nil}
        for effect in clip.effects ?? [] {
            guard let definition=NativeEffectRegistry.definition(for:effect.stableID),definition.supportsAnimation else{continue}
            choices.append(PropertyAnimation(property:.effectStrength,effectID:effect.id))
            for parameter in definition.parameters where parameter.supportsAnimation{
                choices.append(PropertyAnimation(property:.effectParameter,effectID:effect.id,parameter:parameter.name))
            }
        }
        // Keep legacy unsupported curves inspectable, without offering new keys.
        for curve in clip.propertyAnimations ?? [] where !choices.contains(where:{$0.identity==curve.identity}){
            choices.append(curve)
        }
        return choices
    }
    func supportsPropertyAnimation(_ target:PropertyAnimation)->Bool {
        guard let clip=selectedClip else{return false}
        switch target.property {
        case .effectStrength,.effectParameter:
            guard let effect=clip.effects?.first(where:{$0.id==target.effectID}),let definition=NativeEffectRegistry.definition(for:effect.stableID),definition.supportsAnimation else{return false}
            if target.property == .effectStrength{return target.parameter==nil}
            return definition.parameters.contains{$0.name==target.parameter && $0.supportsAnimation}
        default:return target.effectID==nil && target.parameter==nil && target.range(in:clip) != nil && target.baseValue(in:clip) != nil
        }
    }
    func setPropertyKey(_ target:PropertyAnimation,value:Double){
        guard supportsPropertyAnimation(target),canEditPropertyKeys,let clip=selectedClip,let local=selectedPropertyLocalTime else{return}
        do{
            guard value.isFinite,target.range(in:clip)?.contains(value)==true,let base=target.baseValue(in:clip) else{throw DocumentError.invalidTiming}
            var curves=clip.propertyAnimations ?? []
            var curve=curves.first{$0.identity==target.identity} ?? target
            if curve.points.isEmpty{curve.points=[.init(time:.zero,value:base)]}
            try curve.setKey(at:local,value:value)
            if let index=curves.firstIndex(where:{$0.identity==target.identity}){curves[index]=curve}else{curves.append(curve)}
            editSelected{$0.propertyAnimations=curves}
        }catch{self.error=Self.message(error)}
    }
    func removePropertyAnimation(_ target:PropertyAnimation){
        guard canEditPropertyKeys else{return}
        editSelected{clip in clip.propertyAnimations?.removeAll{$0.identity==target.identity};if clip.propertyAnimations?.isEmpty==true{clip.propertyAnimations=nil}}
    }
    func setPropertyInterpolation(_ target:PropertyAnimation,pointID:UUID,curve:Interpolation){
        guard supportsPropertyAnimation(target),canEditPropertyKeys,visiblePropertyKeys(target).contains(where:{$0.point.id==pointID}) else{return}
        editSelected{clip in guard let i=clip.propertyAnimations?.firstIndex(where:{$0.identity==target.identity}),let j=clip.propertyAnimations?[i].points.firstIndex(where:{$0.id==pointID}) else{return};clip.propertyAnimations?[i].points[j].interpolation=curve}
    }
}
