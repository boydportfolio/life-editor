import Foundation
import Testing
@preconcurrency import AVFoundation
import CoreImage
import LifeCore
@testable import LifeMedia

@MainActor private func wordBitmap(_ image:CIImage,size:CGSize)->[UInt8]{
    var bytes=[UInt8](repeating:0,count:Int(size.width*size.height*4))
    CIContext().render(image,toBitmap:&bytes,rowBytes:Int(size.width)*4,bounds:CGRect(origin:.zero,size:size),format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB))
    return bytes
}
private func highlightedTitle()->TitleContent{
    var timing=TitleWordTiming(text:"ONE e\u{301}!\nTWO 👩‍🎤",highlightColor:.init(red:1,green:0.8,blue:0))
    for index in 0..<3{timing.words[index].start = .init(value:Int64(index),timescale:1);timing.words[index].end = .init(value:Int64(index+1),timescale:1)}
    return TitleContent(text:timing.sourceText,fontSize:30,style:.init(x:0.5,y:0.5),wordTiming:timing)
}
@MainActor @Test func explicitWordHighlightUsesFullUnicodeLayoutWithoutGlyphMovement()throws{
    let title=highlightedTitle(),size=CGSize(width:320,height:160)
    var plain=title;plain.wordTiming=nil
    let baseline=wordBitmap(try #require(TitleRenderer.image(plain,size:size)),size:size)
    for time in [RationalTime(value:1,timescale:2),.init(value:3,timescale:2),.init(value:5,timescale:2)]{
        let image=try #require(TitleRenderer.image(title,size:size,localTime:time)),bytes=wordBitmap(image,size:size)
        #expect(bytes != baseline)
        #expect(stride(from:3,to:bytes.count,by:4).allSatisfy{bytes[$0]==baseline[$0]})
        #expect(bytes==wordBitmap(try #require(TitleRenderer.image(title,size:size,localTime:time)),size:size))
    }
    #expect(wordBitmap(try #require(TitleRenderer.image(title,size:size,localTime:.init(value:4,timescale:1))),size:size)==baseline)
    var invalid=title;invalid.wordTiming?.words[0].utf16Location=1
    #expect(wordBitmap(try #require(TitleRenderer.image(invalid,size:size,localTime:.zero)),size:size)==baseline)
    var typewriter=title;typewriter.animation = .init(kind:.typewriter,duration:2)
    let full=try #require(TitleRenderer.image(typewriter,size:size))
    let visible=TitleRenderer.animated(full,title:typewriter,localTime:.init(value:1,timescale:2),canvas:CGRect(origin:.zero,size:size))
    #expect(wordBitmap(visible,size:size) != baseline)
}
@MainActor @Test func wordHighlightsSaveReopenAndMatchActualNativeExportFrames()async throws{
    let root=FileManager.default.temporaryDirectory.appendingPathComponent("life-word-highlight-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
    let size=CGSize(width:256,height:128)
    var timing=TitleWordTiming(text:"ONE TWO",highlightColor:.init(red:1,green:0,blue:0))
    timing.words[0].start = .zero;timing.words[0].end = .init(value:1,timescale:1)
    timing.words[1].start = .init(value:1,timescale:1);timing.words[1].end = .init(value:2,timescale:1)
    let title=TitleContent(text:timing.sourceText,fontSize:36,style:.init(x:0.5,y:0.5),wordTiming:timing)
    let document=ProjectDocument(sequence:Sequence(settings:ProjectSettings(width:256,height:128),tracks:[Track(name:"Words",kind:.caption,clips:[Clip(duration:.init(value:2,timescale:1),title:title)])]))
    let package=root.appendingPathComponent("Words.lifeedit");try ProjectPackage.write(document,to:package)
    let reopened=try ProjectPackage.read(from:package);#expect(reopened==document)
    let pipeline=MediaPipeline(),prepared=try await pipeline.prepare(.init(document:reopened)),preview=AVAssetImageGenerator(asset:prepared.playerItem.asset)
    preview.videoComposition=prepared.playerItem.videoComposition
    let movie=root.appendingPathComponent("Words.mov");try await pipeline.export(.init(document:reopened),to:movie,options:.init(format:.proRes))
    let exported=AVAssetImageGenerator(asset:AVURLAsset(url:movie))
    func centroid(_ image:CGImage)throws->Double{
        let bytes=wordBitmap(CIImage(cgImage:image),size:size)
        var total=0.0,count=0
        for y in 0..<128{for x in 0..<256{let i=(y*256+x)*4;if bytes[i]>140 && bytes[i+1]<70 && bytes[i+2]<70{total+=Double(x);count+=1}}}
        try #require(count>30);return total/Double(count)
    }
    var positions:[Double]=[]
    for time in [CMTime(value:1,timescale:4),CMTime(value:5,timescale:4)]{
        let p=try centroid(try await preview.image(at:time).image),q=try centroid(try await exported.image(at:time).image)
        #expect(abs(p-q)<3);positions.append(p)
    }
    #expect(positions[1]>positions[0]+40)
}
