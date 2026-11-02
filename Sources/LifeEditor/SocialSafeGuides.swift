import SwiftUI

/// Viewer preferences only. These guides never enter a project or render plan.
enum SafeGuideMode:String,CaseIterable {
    case off, titleAction, social
    var title:String {
        switch self {case .off:"Off";case .titleAction:"Title & Action";case .social:"Social"}
    }
    var help:String {
        switch self {
        case .off:"Hide viewer guides"
        case .titleAction:"Title and action guides · preview only"
        case .social:"Conservative social composition guide · preview only; app overlays vary"
        }
    }
}

enum SafeGuidePreferences {
    static let modeKey="safeGuideMode"
    static let defaultKey="showSafeAreaDefault"
    static func preferredMode(in defaults:UserDefaults)->SafeGuideMode {
        guard let raw=defaults.string(forKey:modeKey),let mode=SafeGuideMode(rawValue:raw),mode != .off else{return .titleAction}
        return mode
    }
    static func initialMode(in defaults:UserDefaults)->SafeGuideMode {
        defaults.bool(forKey:defaultKey) ? preferredMode(in:defaults):.off
    }
    static func remember(_ mode:SafeGuideMode,in defaults:UserDefaults) {
        // Keep the last visible style when hidden; the existing startup toggle
        // still decides whether guides appear in a new window.
        if mode != .off {defaults.set(mode.rawValue,forKey:modeKey)}
    }
}

struct SafeGuideGeometry:Equatable {
    let canvas:CGRect
    let outlines:[CGRect]

    static func layout(mode:SafeGuideMode,viewport:CGSize,composition:CGSize)->SafeGuideGeometry? {
        let dimensions=[viewport.width,viewport.height,composition.width,composition.height]
        guard dimensions.allSatisfy({$0.isFinite && $0>0}) else{return nil}
        let scale=min(viewport.width/composition.width,viewport.height/composition.height)
        let size=CGSize(width:composition.width*scale,height:composition.height*scale)
        guard size.width.isFinite,size.height.isFinite,size.width>0,size.height>0 else{return nil}
        let canvas=CGRect(x:(viewport.width-size.width)/2,y:(viewport.height-size.height)/2,width:size.width,height:size.height)
        let outlines:[CGRect]
        switch mode {
        case .off:outlines=[]
        case .titleAction:outlines=[canvas.insetBy(dx:size.width*0.05,dy:size.height*0.05),canvas.insetBy(dx:size.width*0.10,dy:size.height*0.10)]
        case .social:
            // A composition aid, not a promise about any platform's changing UI.
            // Leave more room for bottom descriptions and right-side controls.
            outlines=[CGRect(x:canvas.minX+size.width*0.08,y:canvas.minY+size.height*0.12,width:size.width*0.74,height:size.height*0.66)]
        }
        return .init(canvas:canvas,outlines:outlines)
    }
}

struct SocialSafeGuides:View {
    let mode:SafeGuideMode
    let composition:CGSize
    var body:some View {
        GeometryReader {geometry in
            if let layout=SafeGuideGeometry.layout(mode:mode,viewport:geometry.size,composition:composition) {
                Canvas {context,_ in
                    if mode == .social,let safe=layout.outlines.first {
                        var outside=Path(layout.canvas);outside.addRect(safe)
                        context.fill(outside,with:.color(.black.opacity(0.22)),style:FillStyle(eoFill:true))
                    }
                    for (index,rect) in layout.outlines.enumerated() {
                        let path=Path(rect)
                        context.stroke(path,with:.color(.black.opacity(0.7)),style:StrokeStyle(lineWidth:3,dash:index==1 ? [5,4]:[]))
                        context.stroke(path,with:.color(.white.opacity(0.8)),style:StrokeStyle(lineWidth:1,dash:index==1 ? [5,4]:[]))
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct SafeGuidePicker:View {
    @Binding var mode:SafeGuideMode
    var dismiss:()->Void
    var body:some View {
        HStack(spacing:8) {
            ForEach(SafeGuideMode.allCases,id:\.self) {choice in
                Button {mode=choice;dismiss()} label:{
                    VStack(spacing:6) {
                        ZStack {
                            RoundedRectangle(cornerRadius:3).fill(.black).frame(width:56,height:44)
                            if choice == .off {Image(systemName:"eye.slash").font(.system(size:18)).foregroundStyle(.secondary)}
                            else {SocialSafeGuides(mode:choice,composition:CGSize(width:9,height:16)).frame(width:56,height:44)}
                        }
                        Text(choice.title).font(.caption)
                    }.frame(width:92,height:76)
                        .background(mode==choice ? Color.accentColor.opacity(0.2):.clear,in:RoundedRectangle(cornerRadius:6))
                        .overlay {if mode==choice{RoundedRectangle(cornerRadius:6).stroke(Color.accentColor,lineWidth:1)}}
                }.buttonStyle(.plain).help(choice.help).accessibilityLabel(choice.title)
                    .accessibilityValue(mode==choice ? "Selected":"Not selected")
                    .accessibilityAddTraits(mode==choice ? .isSelected:[])
            }
        }.padding(12)
    }
}
