import SwiftUI
import LifeCore

struct PropertyAnimationControls:View {
    @ObservedObject var store:EditorStore
    @State private var expanded=false
    @State private var keysExpanded=false
    @State private var selectedKeys=Set<UUID>()
    @State private var choiceID=""
    @State private var value=""
    private var target:PropertyAnimation?{store.propertyAnimationChoices.first{$0.identity==choiceID} ?? store.propertyAnimationChoices.first}
    private var curve:PropertyAnimation?{store.selectedClip?.propertyAnimations?.first{$0.identity==target?.identity}}
    private var visibleKeys:[(point:AutomationPoint,local:RationalTime)]{target.map{store.visiblePropertyKeys($0)} ?? []}
    private var editable:Bool{store.canEditPropertyKeys && target.map{store.supportsPropertyAnimation($0)} == true}
    var body:some View {
        if !store.propertyAnimationChoices.isEmpty {
            DisclosureGroup("Animate",isExpanded:$expanded){
                VStack(spacing:8){
                    Picker("Property",selection:Binding(get:{target?.identity ?? ""},set:{choiceID=$0;selectedKeys=[];refresh()})){
                        ForEach(store.propertyAnimationChoices,id:\.identity){item in Text(name(item)+(store.supportsPropertyAnimation(item) ? "":" · Read only")).tag(item.identity)}
                    }.accessibilityLabel("Animated property")
                    HStack(spacing:4){
                        keyButton("backward.end","Previous property key",disabled:target.flatMap{store.adjacentPropertyKey($0,direction:-1)}==nil){if let target{store.selectAdjacentPropertyKey(target,direction:-1)}}
                        TextField("Value",text:$value).textFieldStyle(.roundedBorder).accessibilityLabel("Animated property value").onSubmit{commit()}.disabled(!editable || store.selectedPropertyLocalTime==nil)
                        keyButton("diamond.fill","Set property key at playhead",disabled:!editable || store.selectedPropertyLocalTime==nil){commit()}
                        keyButton("forward.end","Next property key",disabled:target.flatMap{store.adjacentPropertyKey($0,direction:1)}==nil){if let target{store.selectAdjacentPropertyKey(target,direction:1)}}
                        keyButton("list.bullet","Choose property keys",disabled:visibleKeys.isEmpty && !editable){keysExpanded=true}
                        keyButton("arrow.counterclockwise","Remove property animation",disabled:!editable || curve==nil){if let target{store.removePropertyAnimation(target)}}
                    }
                }.padding(.top,8)
            }.popover(isPresented:$keysExpanded){keyChooser}
                .onAppear{refresh()}
                .onChange(of:store.selection){_,_ in selectedKeys=[];refresh()}
                .onChange(of:store.playheadTime){_,_ in refresh()}
                .onChange(of:store.document){_,_ in selectedKeys.formIntersection(Set(visibleKeys.map(\.point.id)));refresh()}
                .disabled(store.placementProposal != nil || store.selectedClip == nil)
        }
    }
    private var keyChooser:some View {
        VStack(spacing:8){
            HStack(spacing:4){
                keyButton("checkmark.circle","Select visible property keys",disabled:visibleKeys.isEmpty){selectedKeys=Set(visibleKeys.map(\.point.id))}
                keyButton("doc.on.doc","Copy selected property keys",disabled:selectedKeys.isEmpty){if let target{store.copyPropertyKeys(target,ids:selectedKeys)}}
                keyButton("doc.on.clipboard","Paste property keys at playhead",disabled:!editable || store.selectedPropertyLocalTime==nil){if let target{store.pastePropertyKeys(target)}}
                Spacer()
                keyButton("trash","Delete selected property keys",disabled:!editable || selectedKeys.isEmpty){if let target{store.removePropertyKeys(target,ids:selectedKeys);selectedKeys=[]}}
            }
            ScrollView{
                VStack(spacing:8){
                    ForEach(visibleKeys,id:\.point.id){entry in
                        HStack(spacing:8){
                            keyButton(selectedKeys.contains(entry.point.id) ? "checkmark.circle.fill":"circle","Select property key at \(entry.local.seconds) seconds",disabled:false){
                                if selectedKeys.contains(entry.point.id){selectedKeys.remove(entry.point.id)}else{selectedKeys.insert(entry.point.id)}
                            }
                            Button{if let clip=store.selectedClip{store.seek(clip.start+entry.local)}}label:{Text(String(format:"%.3f s",entry.local.seconds)).monospacedDigit()}.buttonStyle(.plain).accessibilityLabel("Go to property key")
                            Spacer()
                            Text(String(format:"%.3f",entry.point.value)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Menu(entry.point.interpolation.rawValue.capitalized){
                                ForEach([Interpolation.linear,.eased,.hold],id:\.rawValue){mode in Button(mode.rawValue.capitalized){if let target{store.setPropertyInterpolation(target,pointID:entry.point.id,curve:mode)}}}
                            }.fixedSize().accessibilityLabel("Property key interpolation").disabled(!editable)
                        }
                    }
                }
            }
        }.padding(12).frame(width:350,height:min(300,CGFloat(visibleKeys.count*38+70)))
    }
    private func keyButton(_ symbol:String,_ label:String,disabled:Bool,action:@escaping ()->Void)->some View {
        Button(action:action){Image(systemName:symbol).frame(width:26,height:28)}.buttonStyle(.plain).help(label).accessibilityLabel(label).disabled(disabled)
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
    private func commit(){guard editable,let target,let number=Double(value) else{return};store.setPropertyKey(target,value:number);refresh()}
}
