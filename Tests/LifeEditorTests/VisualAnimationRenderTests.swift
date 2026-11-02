import Foundation
import Testing
import AppKit
import CoreImage
import ImageIO
@preconcurrency import AVFoundation
import LifeCore
import LifeMedia
@testable import LifeEditor

@MainActor @Test(.enabled(if:ProcessInfo.processInfo.environment["LIFE_RUN_MEDIA_INTEGRATION"]=="1"))
func visualAnimationImageTitleAndGraphicSurviveReopenAndMatchDecodedExport()async throws {
    _=NSApplication.shared
    let root=FileManager.default.temporaryDirectory.appendingPathComponent("life-motion-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    defer{try? FileManager.default.removeItem(at:root)}
    let width=160,height=160,source=root.appendingPathComponent("picture.png")
    let context=try #require(CGContext(data:nil,width:160,height:160,bitsPerComponent:8,bytesPerRow:640,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red:1,green:0,blue:0,alpha:1));context.fill(CGRect(x:0,y:0,width:80,height:160))
    context.setFillColor(CGColor(red:0,green:0,blue:1,alpha:1));context.fill(CGRect(x:80,y:0,width:80,height:160))
    let writer=try #require(CGImageDestinationCreateWithURL(source as CFURL,"public.png" as CFString,1,nil))
    CGImageDestinationAddImage(writer,try #require(context.makeImage()),nil);try #require(CGImageDestinationFinalize(writer))
    let pipeline=MediaPipeline(),asset=try await pipeline.probe(source).asset
    let animation=VisualAnimation(keyframes:[
        .init(time:.zero,visual:.init(x:0.25,y:0.5,scaleX:0.5,scaleY:0.5),interpolation:.eased),
        .init(time:.init(value:2,timescale:1),visual:.init(x:0.75,y:0.5,scaleX:0.8,scaleY:0.8))
    ])
    let image=Clip(assetID:asset.id,duration:.init(value:2,timescale:1),visualAnimation:animation)
    let title=Clip(start:.init(value:2,timescale:1),duration:.init(value:2,timescale:1),title:.init(text:"MOVE",fontSize:36,style:.init(y:0.5)),visualAnimation:animation)
    let shape=Clip(start:.init(value:4,timescale:1),duration:.init(value:2,timescale:1),graphic:.shape(.init(kind:.rectangle,fill:.white)),visualAnimation:animation)
    let document=ProjectDocument(sequence:.init(settings:.init(width:width,height:height),tracks:[.init(name:"Image",kind:.image,clips:[image]),.init(name:"Text",kind:.title,clips:[title]),.init(name:"Shape",kind:.shape,clips:[shape])]),assets:[asset])
    let package=root.appendingPathComponent("Motion.lifeedit")
    try ProjectPackage.collect(document,to:package)
    let reopened=try ProjectPackage.read(from:package)
    #expect(reopened.sequence==document.sequence)
    let prepared=try await pipeline.prepare(.init(document:reopened))
    let live=AVAssetImageGenerator(asset:prepared.playerItem.asset);live.videoComposition=prepared.playerItem.videoComposition
    live.requestedTimeToleranceBefore = .zero;live.requestedTimeToleranceAfter = .zero
    let movie=root.appendingPathComponent("motion.mov")
    try await pipeline.export(.init(document:reopened),to:movie,options:.init(format:.proRes))
    let exported=AVAssetImageGenerator(asset:AVURLAsset(url:movie))
    exported.requestedTimeToleranceBefore = .zero;exported.requestedTimeToleranceAfter = .zero
    func pixels(_ image:CGImage)->[UInt8] {
        var bytes=[UInt8](repeating:0,count:width*height*4)
        bytes.withUnsafeMutableBytes{memory in
            let context=CGContext(data:memory.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image,in:CGRect(x:0,y:0,width:width,height:height))
        }
        return bytes
    }
    func brightnessCenter(_ bytes:[UInt8])->Double {
        var sum=0.0,weighted=0.0
        for y in 0..<height{for x in 0..<width{let i=(y*width+x)*4,value=Double(bytes[i])+Double(bytes[i+1])+Double(bytes[i+2]);sum+=value;weighted+=Double(x)*value}}
        return weighted/max(1,sum)
    }
    for start in [0,2,4] {
        var centers:[Double]=[]
        for frame in [15,45] {
            let time=CMTime(value:Int64(start*30+frame),timescale:30)
            let preview=pixels(try await live.image(at:time).image),output=pixels(try await exported.image(at:time).image)
            let difference=zip(preview,output).reduce(0.0){$0+Double(abs(Int($1.0)-Int($1.1)))}/Double(preview.count)
            #expect(difference<5)
            centers.append(brightnessCenter(output))
        }
        #expect(centers[1]>centers[0]+20)
    }
}
