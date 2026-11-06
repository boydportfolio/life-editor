import Foundation

/// SDR neutral-point balance. Samples are sRGB; gains operate in linear RGB.
public enum WhiteBalance {
    public static let stableID="life.adjust.whiteBalance"
    public static let channels=["red","green","blue"]
    public static func linear(_ value:Double)->Double {value<=0.04045 ? value/12.92:pow((value+0.055)/1.055,2.4)}
    public static func parameters(neutral sample:RGBAColor,correcting previous:EffectInstance? = nil)->[String:Double]? {
        guard [sample.red,sample.green,sample.blue,sample.alpha].allSatisfy({$0.isFinite && (0...1).contains($0)}),sample.alpha>=0.99 else{return nil}
        let rgb=[sample.red,sample.green,sample.blue].map(linear)
        let neutral=rgb[0]*0.2126+rgb[1]*0.7152+rgb[2]*0.0722
        guard neutral>=0.005,rgb.allSatisfy({$0>=0.003}) else{return nil}
        var result:[String:Double]=[:]
        for (channel,value) in zip(channels,rgb){
            let old=previous.flatMap{$0.isEnabled ? $0:nil}
            let base=old.map{1+(($0.parameters[channel] ?? 1)-1)*$0.strength} ?? 1
            let gain=base*neutral/value
            guard gain.isFinite,(0.25...4).contains(gain) else{return nil}
            result[channel]=abs(gain-1)<0.000000000001 ? 1:gain
        }
        return result
    }
}
