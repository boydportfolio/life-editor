import AppKit
import Foundation
import Testing
@preconcurrency import AVFoundation
import LifeCore
import LifeMedia
@testable import LifeEditor

@MainActor @Test(.enabled(if:ProcessInfo.processInfo.environment["LIFE_RUN_MEDIA_INTEGRATION"]=="1"))
func appliedFilterAnimationPersistsAndMatchesDecodedPreviewExport()async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent("life-filter-drop-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
    let shape=Clip(duration:.init(value:2,timescale:1),graphic:.shape(.init(kind:.rectangle,rect:.init(x:0,y:0,width:1,height:1),fill:.init(red:1,green:0,blue:0),strokeWidth:0)))
    let store=EditorStore();store.replace(.init(sequence:.init(settings:.init(width:64,height:64),tracks:[.init(name:"Picture",kind:.shape,clips:[shape])])))
    #expect(store.applyFilter("life.filter.grayscale",to:shape.id))
    let effect=try #require(store.selectedClip?.effects?.first)
    store.editSelected{$0.propertyAnimations=[.init(property:.effectStrength,effectID:effect.id,points:[.init(time:.zero,value:0,interpolation:.hold),.init(time:.init(value:1,timescale:1),value:1)])]}
    let original=store.document,package=root.appendingPathComponent("Filter.lifeedit")
    try ProjectPackage.collect(original,to:package);let reopened=try ProjectPackage.read(from:package)
    #expect(reopened.sequence==original.sequence)
    let pipeline=MediaPipeline(),prepared=try await pipeline.prepare(.init(document:reopened))
    let preview=AVAssetImageGenerator(asset:prepared.playerItem.asset);preview.videoComposition=prepared.playerItem.videoComposition
    preview.requestedTimeToleranceBefore = .zero;preview.requestedTimeToleranceAfter = .zero
    let movie=root.appendingPathComponent("filter.mov");try await pipeline.export(.init(document:reopened),to:movie,options:.init(format:.proRes))
    let output=AVAssetImageGenerator(asset:AVURLAsset(url:movie));output.requestedTimeToleranceBefore = .zero;output.requestedTimeToleranceAfter = .zero
    func center(_ image:CGImage)->[Int]{
        var pixels=[UInt8](repeating:0,count:64*64*4)
        pixels.withUnsafeMutableBytes{data in let context=CGContext(data:data.baseAddress,width:64,height:64,bitsPerComponent:8,bytesPerRow:256,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!;context.draw(image,in:CGRect(x:0,y:0,width:64,height:64))}
        return (0..<3).map{Int(pixels[(32*64+32)*4+$0])}
    }
    for seconds in [0.5,1.5] {
        let at=CMTime(seconds:seconds,preferredTimescale:30)
        let live=center(try await preview.image(at:at).image),exported=center(try await output.image(at:at).image)
        #expect(zip(live,exported).allSatisfy{abs($0-$1)<8})
        if seconds<1{#expect(exported[0]>exported[1]+100)}else{#expect(abs(exported[0]-exported[1])<8)}
    }
    store.replace(ProjectDocument())
}
