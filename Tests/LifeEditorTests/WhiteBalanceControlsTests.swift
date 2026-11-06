import Foundation
import AVFoundation
import ImageIO
import CoreGraphics
import CoreImage
import CoreVideo
import Testing
import LifeCore
@testable import LifeEditor

@MainActor private func whiteBalanceStore()->EditorStore{
    let store=EditorStore(),asset=MediaAsset(url:URL(fileURLWithPath:"/tmp/white-balance-source.mov"),kind:.video,duration:.init(value:5,timescale:1)),clip=Clip(duration:.init(value:5,timescale:1))
    var source=clip;source.assetID=asset.id
    store.replace(ProjectDocument(sequence:Sequence(tracks:[Track(name:"Camera",kind:.video,clips:[source])]),assets:[asset]))
    store.selection=source.id;store.preparing=false
    return store
}
@MainActor @Test func whiteBalancePickIsOneUndoablePersistedEdit()throws{
    let store=whiteBalanceStore(),before=store.document,context=WhiteBalanceSamplingContext(store:store,clip:try #require(store.selectedClip))
    store.applyWhiteBalanceSample(.init(red:0.7,green:0.5,blue:0.4),context:context,sourceIsOpaque:true)
    let after=store.document,effect=try #require(store.selectedClip?.effects?.first)
    #expect(effect.stableID==WhiteBalance.stableID && effect.parameters["red"]!<1 && effect.parameters["blue"]!>1)
    #expect(try ProjectDocument.decode(JSONEncoder().encode(after))==after)
    store.undo();#expect(store.document==before);store.redo();#expect(store.document==after)
    store.resetWhiteBalance();#expect(store.selectedClip?.effects?.isEmpty==true)
    store.undo();#expect(store.document==after)
}
@MainActor @Test func whiteBalancePickRejectsStaleSessionFrameSelectionAndLayers()throws{
    let sample=RGBAColor(red:0.7,green:0.5,blue:0.4)
    for reason in 0..<5{
        let store=whiteBalanceStore(),context=WhiteBalanceSamplingContext(store:store,clip:try #require(store.selectedClip))
        switch reason{
        case 0:store.projectGeneration+=1
        case 1:store.playheadTime = .init(value:1,timescale:1)
        case 2:store.selection=nil
        case 3:store.player.replaceCurrentItem(with:AVPlayerItem(asset:AVMutableComposition()))
        default:store.document.sequence.tracks.append(Track(name:"Overlay",kind:.title,clips:[Clip(duration:.init(value:5,timescale:1),title:.init(text:"Overlay"))]))
        }
        let before=store.document
        store.applyWhiteBalanceSample(sample,context:context,sourceIsOpaque:true)
        #expect(store.document==before)
    }
}
@MainActor @Test func whiteBalancePickRejectsAlphaAndPostBalanceEffects()throws{
    let store=whiteBalanceStore(),context=WhiteBalanceSamplingContext(store:store,clip:try #require(store.selectedClip)),before=store.document
    store.applyWhiteBalanceSample(.init(red:0.7,green:0.5,blue:0.4),context:context,sourceIsOpaque:false)
    #expect(store.document==before && store.error != nil)
    store.error=nil
    store.editSelected{$0.effects=[NativeEffectRegistry.make(WhiteBalance.stableID),NativeEffectRegistry.make("life.adjust.saturation")]}
    let changed=store.document,newContext=WhiteBalanceSamplingContext(store:store,clip:try #require(store.selectedClip));store.preparing=false
    store.applyWhiteBalanceSample(.init(red:0.7,green:0.5,blue:0.4),context:newContext,sourceIsOpaque:true)
    #expect(store.document==changed)
}

@MainActor @Test func whiteBalanceOpacityProbeRejectsAlphaAndRemoteSources()async throws{
    let root=FileManager.default.temporaryDirectory.appendingPathComponent("life-wb-alpha-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
    for alpha in [false,true]{
        let values:[UInt8]=alpha ? [120,100,80,128]:[120,100,80]
        let provider=try #require(CGDataProvider(data:Data(values) as CFData))
        let image=try #require(CGImage(width:1,height:1,bitsPerComponent:8,bitsPerPixel:alpha ? 32:24,bytesPerRow:alpha ? 4:3,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:(alpha ? CGImageAlphaInfo.last:CGImageAlphaInfo.none).rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent))
        let url=root.appendingPathComponent("\(alpha).png"),destination=try #require(CGImageDestinationCreateWithURL(url as CFURL,"public.png" as CFString,1,nil))
        CGImageDestinationAddImage(destination,image,nil);try #require(CGImageDestinationFinalize(destination))
        let asset=MediaAsset(url:url,kind:.image,duration:.init(value:1,timescale:1))
        #expect(try await EditorStore.whiteBalanceSourceIsOpaque(asset) == !alpha)
    }
    let remote=MediaAsset(url:URL(string:"https://example.com/video.mov")!,kind:.video,duration:.init(value:1,timescale:1))
    #expect(!(try await EditorStore.whiteBalanceSourceIsOpaque(remote)))
}

@MainActor @Test func whiteBalanceViewerSampleConvertsKnownRec709OutputToSRGB()throws{
    var buffer:CVPixelBuffer?;try #require(CVPixelBufferCreate(nil,2,2,kCVPixelFormatType_32BGRA,nil,&buffer)==kCVReturnSuccess)
    let pixels=try #require(buffer),linear=CGColorSpace(name:CGColorSpace.linearSRGB)!,srgb=CGColorSpace(name:CGColorSpace.sRGB)!,rec709=CGColorSpace(name:CGColorSpace.itur_709)!
    let source=CIImage(color:try #require(CIColor(red:0.4,green:0.2,blue:0.1,alpha:1,colorSpace:linear))).cropped(to:CGRect(x:0,y:0,width:2,height:2))
    let context=CIContext(options:[.workingColorSpace:linear,.outputColorSpace:rec709])
    context.render(source,to:pixels,bounds:source.extent,colorSpace:rec709)
    let sample=try #require(ViewerColorSampler.sample(pixels,x:0.5,y:0.5))
    var expected=[UInt8](repeating:0,count:4)
    context.render(source,toBitmap:&expected,rowBytes:4,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBA8,colorSpace:srgb)
    for (actual,byte) in zip([sample.red,sample.green,sample.blue],expected.prefix(3)){
        #expect(abs(actual-Double(byte)/255)<=2.0/255)
    }
}

@MainActor @Test func whiteBalanceRepeatedPickIgnoresTrailingDisabledAdjustments()throws{
    let store=whiteBalanceStore()
    var trailing=NativeEffectRegistry.make("life.adjust.saturation");trailing.isEnabled=false
    let balance=NativeEffectRegistry.make(WhiteBalance.stableID)
    store.editSelected{$0.effects=[balance,trailing]}
    store.preparing=false
    let context=WhiteBalanceSamplingContext(store:store,clip:try #require(store.selectedClip))
    store.applyWhiteBalanceSample(.init(red:0.6,green:0.5,blue:0.4),context:context,sourceIsOpaque:true)
    #expect(store.selectedClip?.effects?.filter{$0.stableID==WhiteBalance.stableID}.count==1)
    #expect(store.selectedClip?.effects?.first?.id==balance.id)
    #expect(store.selectedClip?.effects?.last==trailing)
    store.preparing=false
    let again=WhiteBalanceSamplingContext(store:store,clip:try #require(store.selectedClip))
    store.applyWhiteBalanceSample(.init(red:0.5,green:0.5,blue:0.5),context:again,sourceIsOpaque:true)
    #expect(store.error==nil)
    #expect(store.selectedClip?.effects?.filter{$0.stableID==WhiteBalance.stableID}.count==1)
}

@MainActor @Test func whiteBalanceRejectsStaleNativeDisplayFrames(){
    let expected=RationalTime(value:2,timescale:1),rate=FrameRate()
    #expect(ViewerColorSampler.frameMatches(expected:expected,actual:CMTime(value:2,timescale:1),rate:rate))
    #expect(!ViewerColorSampler.frameMatches(expected:expected,actual:CMTime(value:59,timescale:30),rate:rate))
    #expect(!ViewerColorSampler.frameMatches(expected:expected,actual:.zero,rate:rate))
    #expect(!ViewerColorSampler.frameMatches(expected:expected,actual:.invalid,rate:rate))
    #expect(ViewerColorSampler.frameMatches(expected:expected,actual:CMTime(seconds:2.001,preferredTimescale:48000),rate:rate))
}

@MainActor @Test func whiteBalanceReenabledPickMovesAfterExistingColorAdjustments()throws{
    let store=whiteBalanceStore()
    var balance=NativeEffectRegistry.make(WhiteBalance.stableID);balance.isEnabled=false
    let adjustment=NativeEffectRegistry.make("life.adjust.saturation")
    store.editSelected{$0.effects=[balance,adjustment]};store.preparing=false
    let context=WhiteBalanceSamplingContext(store:store,clip:try #require(store.selectedClip))
    store.applyWhiteBalanceSample(.init(red:0.6,green:0.5,blue:0.4),context:context,sourceIsOpaque:true)
    #expect(store.selectedClip?.effects?.last?.id==balance.id)
    #expect(store.selectedClip?.effects?.first==adjustment)
    #expect(store.selectedClip?.effects?.filter{$0.stableID==WhiteBalance.stableID}.count==1)
    #expect(store.error==nil)
}
