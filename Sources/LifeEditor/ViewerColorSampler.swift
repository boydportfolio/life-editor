import AVFoundation
import CoreImage
import CoreVideo
import LifeCore

@MainActor enum ViewerColorSampler {
    private static let context=CIContext(options:[.cacheIntermediates:false])
    static func frameMatches(expected:RationalTime,actual:CMTime,rate:FrameRate)->Bool{
        actual.isNumeric && actual.seconds.isFinite && abs(actual.seconds-expected.seconds)<=rate.frameDuration.seconds/2+0.0000001
    }
    static func sample(_ output:AVPlayerItemVideoOutput?,at time:RationalTime,rate:FrameRate,x:Double,y:Double)->RGBAColor?{
        var actual=CMTime.invalid
        let requested=CMTime(value:time.value,timescale:CMTimeScale(time.timescale))
        guard let buffer=output?.copyPixelBuffer(forItemTime:requested,itemTimeForDisplay:&actual),frameMatches(expected:time,actual:actual,rate:rate) else{return nil}
        return sample(buffer,x:x,y:y)
    }
    static func sample(_ buffer:CVPixelBuffer,x:Double,y:Double)->RGBAColor?{
        guard x.isFinite,y.isFinite,(0...1).contains(x),(0...1).contains(y) else{return nil}
        let width=CVPixelBufferGetWidth(buffer),height=CVPixelBufferGetHeight(buffer)
        guard width>0,height>0 else{return nil}
        let px=min(width-1,Int(x*Double(width))),py=min(height-1,Int((1-y)*Double(height)))
        let bounds=CGRect(x:px,y:py,width:1,height:1)
        // LifeVideoCompositor writes Rec.709 BGRA; render-context buffers do
        // not reliably carry a color-space attachment. Avoid assuming sRGB.
        let image=CIImage(cvPixelBuffer:buffer,options:[.colorSpace:CGColorSpace(name:CGColorSpace.itur_709)!]).cropped(to:bounds).transformed(by:CGAffineTransform(translationX:-CGFloat(px),y:-CGFloat(py)))
        var bytes=[UInt8](repeating:0,count:4)
        context.render(image,toBitmap:&bytes,rowBytes:4,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB))
        return RGBAColor(red:Double(bytes[0])/255,green:Double(bytes[1])/255,blue:Double(bytes[2])/255,alpha:Double(bytes[3])/255)
    }
}
