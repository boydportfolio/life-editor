import Testing
@preconcurrency import AVFoundation
import CoreImage
import LifeCore
@testable import LifeMedia

private func balancePixels(_ image:CIImage)->[Float]{
    let space=CGColorSpace(name:CGColorSpace.linearSRGB)!,context=CIContext(options:[.workingColorSpace:space,.outputColorSpace:space])
    var values=[Float](repeating:0,count:4)
    values.withUnsafeMutableBytes{context.render(image,toBitmap:$0.baseAddress!,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:space)}
    return values
}
@Test func whiteBalanceRendererNeutralizesLinearChannelsAndPreservesAlpha()throws{
    let sample=RGBAColor(red:0.7,green:0.5,blue:0.4),parameters=try #require(WhiteBalance.parameters(neutral:sample))
    let effect=EffectInstance(stableID:WhiteBalance.stableID,parameters:parameters)
    for alpha in [Float(1),0.5,0]{
        let values:[Float]=[Float(sample.red)*alpha,Float(sample.green)*alpha,Float(sample.blue)*alpha,alpha]
        let image=values.withUnsafeBytes{CIImage(bitmapData:Data($0),bytesPerRow:16,size:CGSize(width:1,height:1),format:.RGBAf,colorSpace:CGColorSpace(name:CGColorSpace.sRGB))}
        let before=balancePixels(image),after=balancePixels(EffectRenderer.apply([effect],to:image))
        #expect(abs(after[0]-after[1])<0.00002 && abs(after[1]-after[2])<0.00002)
        #expect(abs(after[3]-alpha)<0.00001)
        #expect(balancePixels(EffectRenderer.apply([NativeEffectRegistry.make(WhiteBalance.stableID)],to:image))==before)
        var bypass=effect;bypass.isEnabled=false
        #expect(balancePixels(EffectRenderer.apply([bypass],to:image))==before)
        var zero=effect;zero.strength=0
        #expect(balancePixels(EffectRenderer.apply([zero],to:image))==before)
    }
}

@MainActor @Test func whiteBalanceMatchesSavedReopenedNativePreviewAndExport()async throws{
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent("life-white-balance-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:directory)}
    let graphic=Clip(duration:.init(value:1,timescale:1),graphic:.shape(.init(kind:.rectangle,rect:.init(x:0,y:0,width:1,height:1),fill:.init(red:0.7,green:0.5,blue:0.4),strokeWidth:0)))
    var document=ProjectDocument(sequence:Sequence(settings:ProjectSettings(width:64,height:64),tracks:[Track(name:"Warm gray",kind:.shape,clips:[graphic])]))
    let pipeline=MediaPipeline(),time=CMTime(value:1,timescale:2)
    func pixel(_ image:CGImage)->[UInt8]{
        var values=[UInt8](repeating:0,count:4)
        values.withUnsafeMutableBytes{let context=CGContext(data:$0.baseAddress,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!;context.draw(image,in:CGRect(x:0,y:0,width:1,height:1))}
        return values
    }
    let base=try await pipeline.prepare(.init(document:document)) 
    let reader=try AVAssetReader(asset:base.playerItem.asset)
    let tracks=try await base.playerItem.asset.loadTracks(withMediaType:.video)
    let output=AVAssetReaderVideoCompositionOutput(videoTracks:tracks,videoSettings:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA])
    output.videoComposition=base.playerItem.videoComposition;reader.add(output)
    reader.timeRange=CMTimeRange(start:time,duration:CMTime(value:1,timescale:30))
    try #require(reader.startReading())
    let buffer=try #require(output.copyNextSampleBuffer().flatMap{CMSampleBufferGetImageBuffer($0)})
    let sampledImage=CIImage(cvPixelBuffer:buffer,options:[.colorSpace:CGColorSpace(name:CGColorSpace.itur_709)!])
    var sampled=[UInt8](repeating:0,count:4)
    CIContext().render(sampledImage,toBitmap:&sampled,rowBytes:4,bounds:CGRect(x:32,y:32,width:1,height:1),format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB))
    reader.cancelReading()
    let parameters=try #require(WhiteBalance.parameters(neutral:.init(red:Double(sampled[0])/255,green:Double(sampled[1])/255,blue:Double(sampled[2])/255)))
    document.sequence.tracks[0].clips[0].effects=[EffectInstance(stableID:WhiteBalance.stableID,parameters:parameters)]
    let package=directory.appendingPathComponent("Balanced.lifeedit");try ProjectPackage.write(document,to:package)
    let reopened=try ProjectPackage.read(from:package);#expect(reopened==document)
    let prepared=try await pipeline.prepare(.init(document:reopened)),preview=AVAssetImageGenerator(asset:prepared.playerItem.asset);preview.videoComposition=prepared.playerItem.videoComposition
    let p=pixel(try await preview.image(at:time).image)
    #expect(Int(p.prefix(3).max()!)-Int(p.prefix(3).min()!)<8)
    let movie=directory.appendingPathComponent("Balanced.mov");try await pipeline.export(.init(document:reopened),to:movie,options:.init(format:.proRes))
    let q=pixel(try await AVAssetImageGenerator(asset:AVURLAsset(url:movie)).image(at:time).image)
    #expect(Int(q.prefix(3).max()!)-Int(q.prefix(3).min()!)<10)
    for channel in 0..<3{#expect(abs(Int(p[channel])-Int(q[channel]))<20)}
}
