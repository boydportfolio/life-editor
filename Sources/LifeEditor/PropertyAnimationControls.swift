import SwiftUI
import LifeCore

struct PropertyAnimationControls:View {
    @ObservedObject var store:EditorStore
    @State private var expanded=false
    @State private var choiceID=""
    @State private var value=""
    private var target:PropertyAnimation?{store.propertyAnimationChoices.first{$0.identity==choiceID} ?? store.propertyAnimationChoices.first}
    private var curve:PropertyAnimation?{store.selectedClip?.propertyAnimations?.first{$0.identity==target?.identity}}
    var body:some View {
        if !store.propertyAnimationChoices.isEmpty {
            DisclosureGroup("Animate",isExpanded:$expanded){
                VStack(spacing:8){
                    Picker("Property",selection:Binding(get:{target?.identity ?? ""},set:{choiceID=$0;refresh()})){
                        ForEach(store.propertyAnimationChoices,id:\.identity){item in Text(name(item)).tag(item.identity)}
                    }.accessibilityLabel("Animated property")
                    HStack{
                        TextField("Value",text:$value).textFieldStyle(.roundedBorder).accessibilityLabel("Animated property value").onSubmit{commit()}
                        Button{commit()}label:{Image(systemName:"diamond.fill").frame(width:28,height:28)}.help("Set key at playhead").accessibilityLabel("Set property key at playhead")
                        Button{if let target{store.removePropertyAnimation(target)}}label:{Image(systemName:"arrow.counterclockwise").frame(width:28,height:28)}.help("Remove property animation").accessibilityLabel("Remove property animation").disabled(curve==nil)
                    }
                    if let curve {
                        ForEach(curve.points){point in
                            if let local=try? curve.localTime(for:point),let clip=store.selectedClip,local >= .zero,local<=clip.duration {
                                HStack{
                                    Button{store.seek(clip.start+local)}label:{Text(String(format:"%.3f s",local.seconds)).monospacedDigit()}.buttonStyle(.plain).accessibilityLabel("Go to property key")
                                    Spacer()
                                    Menu(point.interpolation.rawValue.capitalized){
                                        ForEach([Interpolation.linear,.eased,.hold],id:\.rawValue){mode in Button(mode.rawValue.capitalized){if let target{store.setPropertyInterpolation(target,pointID:point.id,curve:mode)}}}
                                    }.fixedSize().accessibilityLabel("Property key interpolation")
                                }
                            }
                        }
                    }
                }.padding(.top,8)
            }.onAppear{refresh()}.onChange(of:store.selection){_,_ in refresh()}.onChange(of:store.playheadTime){_,_ in refresh()}
                .disabled(store.placementProposal != nil || store.selectedClip == nil)
        }
    }
    private func name(_ target:PropertyAnimation)->String {
        if let id=target.effectID,let effect=store.selectedClip?.effects?.first(where:{$0.id==id}){return (NativeEffectRegistry.definition(for:effect.stableID)?.name ?? "Effect")+" · "+(target.parameter ?? "Strength")}
        switch target.property {
        case .titleSize:return "Text size"
        case .textRed:return "Text · red"
        case .textGreen:return "Text · green"
        case .textBlue:return "Text · blue"
        case .textAlpha:return "Text opacity"
        case .backgroundAlpha:return "Background opacity"
        case .drawingWidth:return "Drawing width"
        case .drawingRed:return "Drawing · red"
        case .drawingGreen:return "Drawing · green"
        case .drawingBlue:return "Drawing · blue"
        case .drawingAlpha:return "Drawing opacity"
        default:return target.property.rawValue
        }
    }
    private func refresh(){if let target,let clip=store.selectedEvaluatedProperties,let number=target.baseValue(in:clip){value=String(format:"%.4f",number)}}
    private func commit(){guard let target,let number=Double(value) else{return};store.setPropertyKey(target,value:number);refresh()}
}
