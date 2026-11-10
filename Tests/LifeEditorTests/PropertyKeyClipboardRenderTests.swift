import AppKit
import CoreGraphics
import Foundation
import Testing
@preconcurrency import AVFoundation
import LifeCore
import LifeMedia
@testable import LifeEditor

@MainActor @Test(.enabled(if:ProcessInfo.processInfo.environment["LIFE_RUN_MEDIA_INTEGRATION"]=="1"))
func pastedEffectPropertyKeysSurviveReopenAndMatchNativePreviewExport()async throws {
    _=NSApplication.shared
    let root=FileManager.default.temporaryDirectory.appendingPathComponent("life-property-key-render-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    defer{try? FileManager.default.removeItem(at:root)}
    let store=EditorStore(),sourceEffect=NativeEffectRegistry.make("life.filter.grayscale"),targetEffect=NativeEffectRegistry.make("life.filter.grayscale")
    let picture=GraphicContent.shape(.init(kind:.rectangle,rect:.init(x:0,y:0,width:1,height:1),fill:.init(red:1,green:0,blue:0),strokeWidth:0))
    let sourceTarget=PropertyAnimation(property:.effectStrength,effectID:sourceEffect.id)
    let source=Clip(duration:.init(value:2,timescale:1),effects:[sourceEffect],graphic:picture,propertyAnimations:[.init(property:.effectStrength,effectID:sourceEffect.id,points:[.init(time:.zero,value:0),.init(time:.init(value:4,timescale:1),value:1)],timeScale:.init(value:2,timescale:1))])
    store.replace(ProjectDocument(sequence:.init(settings:.init(width:64,height:64),tracks:[.init(name:"Source",kind:.shape,clips:[source])])))
    store.selection=source.id
    let data=try #require(try store.encodedPropertyKeys(sourceTarget,ids:Set(store.visiblePropertyKeys(sourceTarget).map(\.point.id))))
    let destination=Clip(duration:.init(value:2,timescale:1),effects:[targetEffect],graphic:picture)
    store.replace(ProjectDocument(sequence:.init(settings:.init(width:64,height:64),tracks:[.init(name:"Pasted",kind:.shape,clips:[destination])])))
    store.selection=destination.id;store.seek(0)
    store.pastePropertyKeys(.init(property:.effectStrength,effectID:targetEffect.id),data:data)
    #expect(store.error==nil)
    let package=root.appendingPathComponent("Pasted.lifeedit")
    try ProjectPackage.collect(store.document,to:package)
    let reopened=try ProjectPackage.read(from:package)
    #expect(reopened.sequence==store.document.sequence)
    let media=MediaPipeline(),prepared=try await media.prepare(.init(document:reopened))
    let preview=AVAssetImageGenerator(asset:prepared.playerItem.asset);preview.videoComposition=prepared.playerItem.videoComposition
    preview.requestedTimeToleranceBefore = .zero;preview.requestedTimeToleranceAfter = .zero
    let url=root.appendingPathComponent("pasted.mov")
    try await media.export(.init(document:reopened),to:url,options:.init(format:.proRes))
    let exported=AVAssetImageGenerator(asset:AVURLAsset(url:url))
    exported.requestedTimeToleranceBefore = .zero;exported.requestedTimeToleranceAfter = .zero
    func pixels(_ image:CGImage)->[UInt8]{
        var bytes=[UInt8](repeating:0,count:64*64*4)
        bytes.withUnsafeMutableBytes{memory in
            let context=CGContext(data:memory.baseAddress,width:64,height:64,bitsPerComponent:8,bytesPerRow:256,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image,in:CGRect(x:0,y:0,width:64,height:64))
        }
        return bytes
    }
    var red:[Int]=[],green:[Int]=[]
    for numerator in [1,3]{
        let at=CMTime(value:Int64(numerator),timescale:2)
        let live=pixels(try await preview.image(at:at).image),delivered=pixels(try await exported.image(at:at).image)
        let difference=zip(live,delivered).reduce(0.0){$0+Double(abs(Int($1.0)-Int($1.1)))}/Double(live.count)
        #expect(difference<5)
        let center=(32*64+32)*4;red.append(Int(delivered[center]));green.append(Int(delivered[center+1]))
    }
    #expect(red[0]>red[1]+15 && green[1]>green[0]+15)
}
