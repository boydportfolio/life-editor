import Foundation
import Testing
@preconcurrency import AVFoundation
import CoreImage
import LifeCore
@testable import LifeMedia

@Test func captionBurnInDefaultsOnAndNeverChangesProjectTimingOrOtherOverlays()throws {
    let cue=CaptionCue(start:.init(value:1,timescale:1),duration:.init(value:2,timescale:1),text:"Words")
    let title=Clip(name:"Logo",duration:.init(value:1,timescale:1),title:.init(text:"Logo"))
    let document=ProjectDocument(sequence:.init(settings:.init(width:180,height:320),tracks:[
        .init(name:"Captions",kind:.caption,clips:[cue.clip]),
        .init(name:"Hidden captions",kind:.caption,clips:[],isHidden:true),
        .init(name:"Title",kind:.title,clips:[title])]))
    #expect(ExportOptions().burnInCaptions)
    #expect(ExportOptions().applying(to:document)==document)
    let clean=ExportOptions(burnInCaptions:false).applying(to:document)
    #expect(clean.sequence.duration==document.sequence.duration)
    #expect(clean.sequence.settings==document.sequence.settings)
    #expect(clean.sequence.tracks[0].clips==document.sequence.tracks[0].clips)
    #expect(clean.sequence.tracks[0].isHidden && clean.sequence.tracks[1].isHidden)
    #expect(clean.sequence.tracks[2]==document.sequence.tracks[2])
    #expect(!document.sequence.tracks[0].isHidden)
    try clean.validate()
    #expect(try SRT.encode([cue])==SRT.encode(clean.sequence.tracks[0].clips.map{CaptionCue(start:$0.start,duration:$0.duration,text:$0.title!.text)}))
}

@MainActor @Test(.enabled(if:ProcessInfo.processInfo.environment["LIFE_RUN_MEDIA_INTEGRATION"]=="1"))
func captionBurnInChoiceMatchesCleanAndStyledPreviewAndPreservesRange()async throws {
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent("life-caption-export-\(UUID())")
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    defer{try? FileManager.default.removeItem(at:directory)}
    let caption=try CaptionPreset.pill.applying(to:CaptionCue(start:.zero,duration:.init(value:2,timescale:1),text:"One more take").clip,canvasHeight:320)
    let title=Clip(name:"Title",duration:.init(value:2,timescale:1),title:.init(text:"Life",fontSize:28,style:.init(y:0.25)))
    let document=ProjectDocument(sequence:.init(settings:.init(width:180,height:320),tracks:[
        .init(name:"Title",kind:.title,clips:[title]),.init(name:"Captions",kind:.caption,clips:[caption])]))
    let package=directory.appendingPathComponent("Captions.lifeedit")
    try ProjectPackage.write(document,to:package)
    let reopened=try ProjectPackage.read(from:package),snapshot=ProjectSnapshot(document:reopened),pipeline=MediaPipeline()
    var rendered:[Bool:[UInt8]]=[:]
    func pixels(_ image:CGImage)->[UInt8] {
        var bytes=[UInt8](repeating:0,count:180*320*4)
        CIContext().render(CIImage(cgImage:image),toBitmap:&bytes,rowBytes:180*4,bounds:CGRect(x:0,y:0,width:180,height:320),format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB))
        return bytes
    }
    for burnIn in [true,false] {
        let options=ExportOptions(format:.proRes,rangeStart:.init(value:1,timescale:2),rangeDuration:.init(value:1,timescale:1),burnInCaptions:burnIn)
        let prepared=try await pipeline.prepare(.init(document:options.applying(to:reopened)))
        let preview=AVAssetImageGenerator(asset:prepared.playerItem.asset);preview.videoComposition=prepared.playerItem.videoComposition
        preview.requestedTimeToleranceBefore = .zero;preview.requestedTimeToleranceAfter = .zero
        let live=pixels(try await preview.image(at:CMTime(value:1,timescale:1)).image)
        let destination=directory.appendingPathComponent(burnIn ? "captioned.mov":"clean.mov")
        try await pipeline.export(snapshot,to:destination,options:options)
        let asset=AVURLAsset(url:destination),output=AVAssetImageGenerator(asset:asset)
        output.requestedTimeToleranceBefore = .zero;output.requestedTimeToleranceAfter = .zero
        let image=try await output.image(at:CMTime(value:1,timescale:2)).image
        #expect(image.width==180 && image.height==320)
        #expect(abs(try await asset.load(.duration).seconds-1)<0.001)
        let offline=pixels(image),difference=zip(live,offline).reduce(0.0){$0+Double(abs(Int($1.0)-Int($1.1)))}/Double(live.count)
        #expect(difference<5)
        // The ordinary title remains in both deliveries.
        #expect(stride(from:0,to:180*160*4,by:4).filter{offline[$0]>100}.count>50)
        rendered[burnIn]=offline
    }
    let captioned=try #require(rendered[true]),clean=try #require(rendered[false])
    #expect(zip(captioned,clean).filter{abs(Int($0)-Int($1))>30}.count>100)
    #expect(try ProjectPackage.read(from:package)==document)
}
