import Foundation
import LifeCore

extension EditorStore {
    func setCanvas(_ preset:ExportCanvas){
        guard !busy else{error="Finish importing before changing the canvas.";return}
        guard let dimensions=preset.dimensions(shortEdge:1080) else{return}
        var next=document
        next.sequence.settings.width=dimensions.width
        next.sequence.settings.height=dimensions.height
        next.sequence.settings.canvasIsExplicit=true
        replace(next)
    }
    /// An explicit canvas survives first import and reopening; source rate still
    /// supplies the initial exact project clock, independently of its aspect.
    static func firstVideoSettings(width:Int,height:Int,rate:Double,current:ProjectSettings)->ProjectSettings {
        var settings=current
        if settings.canvasIsExplicit != true {settings.width=width;settings.height=height}
        if rate.isFinite,rate>0,rate<=240 {
            let known:[(Double,FrameRate)]=[(29.97,.init(numerator:30000,denominator:1001)),(59.94,.init(numerator:60000,denominator:1001)),(23.976,.init(numerator:24000,denominator:1001))]
            settings.frameRate=known.first(where:{abs($0.0-rate)<0.02})?.1 ?? .init(numerator:Int64(max(1,rate.rounded())))
        }
        return settings
    }
}
