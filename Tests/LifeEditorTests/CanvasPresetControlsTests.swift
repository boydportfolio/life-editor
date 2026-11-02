import Foundation
import Testing
import LifeCore
import LifeMedia
@preconcurrency import AVFoundation
import CoreImage
@testable import LifeEditor

@MainActor @Test func canvasPresetsPersistUndoAndKeepClipContentAndTiming()throws {
    let store=EditorStore();store.addManualCaption()
    let original=store.document
    for preset in ExportCanvas.allCases where preset != .project {
        store.setCanvas(preset)
        let changed=store.document,size=try #require(preset.dimensions(shortEdge:1080))
        #expect(changed.sequence.settings.width==size.width && changed.sequence.settings.height==size.height)
        #expect(changed.sequence.settings.canvasIsExplicit==true)
        #expect(changed.sequence.tracks==original.sequence.tracks)
        #expect(changed.sequence.settings.frameRate==original.sequence.settings.frameRate)
        try changed.validate()
        #expect(try ProjectDocument.decode(changed.encoded())==changed)
        store.undo();#expect(store.document==original)
        store.redo();#expect(store.document==changed)
        store.undo()
    }
}

@MainActor @Test func explicitCanvasSurvivesFirstVideoDefaultsAndLegacySettingsStayAutomatic()throws {
    let legacy=Data(#"{"width":1920,"height":1080,"frameRate":{"numerator":30,"denominator":1},"audioSampleRate":48000}"#.utf8)
    let settings=try JSONDecoder().decode(ProjectSettings.self,from:legacy)
    #expect(settings.canvasIsExplicit==nil)
    let automatic=EditorStore.firstVideoSettings(width:1280,height:720,rate:29.97,current:settings)
    #expect(automatic.width==1280 && automatic.height==720)
    #expect(automatic.frameRate==FrameRate(numerator:30000,denominator:1001))
    let store=EditorStore();store.setCanvas(.portrait)
    let reopened=try ProjectDocument.decode(store.document.encoded())
    let fixed=EditorStore.firstVideoSettings(width:1280,height:720,rate:59.94,current:reopened.sequence.settings)
    #expect(fixed.width==1080 && fixed.height==1920)
    #expect(fixed.frameRate==FrameRate(numerator:60000,denominator:1001))
    #expect(EditorStore.firstVideoSettings(width:1280,height:720,rate:.nan,current:fixed).frameRate==fixed.frameRate)
    #expect(EditorStore.firstVideoSettings(width:1280,height:720,rate:0.1,current:fixed).frameRate==FrameRate(numerator:1))
}

@MainActor @Test func canvasChangesRejectPendingPlacementAndImport(){
    let store=EditorStore();store.addManualCaption()
    let before=store.document,clip=store.selectedClip!
    store.previewPlacement(.insertCopies(clipIDs:[clip.id],at:clip.end),title:"Insert")
    store.setCanvas(.portrait);#expect(store.document==before)
    store.cancelPlacement();store.busy=true
    store.setCanvas(.square);#expect(store.document==before)
}

@MainActor @Test(.enabled(if:ProcessInfo.processInfo.environment["LIFE_RUN_MEDIA_INTEGRATION"]=="1"))
func canvasPresetProducesPortraitPreviewAndExportAfterReopen()async throws {
    let store=EditorStore();store.addManualCaption();store.setCanvas(.portrait)
    store.editSelected{$0.duration = .init(value:1,timescale:5)}
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent("life-canvas-\(UUID())")
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    defer{try? FileManager.default.removeItem(at:directory)}
    let package=directory.appendingPathComponent("Portrait.lifeedit")
    try ProjectPackage.write(store.document,to:package)
    let reopened=try ProjectPackage.read(from:package),pipeline=MediaPipeline(),snapshot=ProjectSnapshot(document:reopened)
    let prepared=try await pipeline.prepare(snapshot)
    let preview=AVAssetImageGenerator(asset:prepared.playerItem.asset);preview.videoComposition=prepared.playerItem.videoComposition
    let live=try await preview.image(at:CMTime(value:1,timescale:10)).image
    let destination=directory.appendingPathComponent("portrait.mp4")
    try await pipeline.export(snapshot,to:destination)
    let output=try await AVAssetImageGenerator(asset:AVURLAsset(url:destination)).image(at:CMTime(value:1,timescale:10)).image
    #expect(live.width==1080 && live.height==1920)
    #expect(output.width==1080 && output.height==1920)
    func pixels(_ image:CGImage)->[UInt8] {
        var bytes=[UInt8](repeating:0,count:90*160*4)
        let scaled=CIImage(cgImage:image).transformed(by:CGAffineTransform(scaleX:1.0/12,y:1.0/12))
        CIContext().render(scaled,toBitmap:&bytes,rowBytes:90*4,bounds:CGRect(x:0,y:0,width:90,height:160),format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB))
        return bytes
    }
    let expected=pixels(live),actual=pixels(output)
    #expect(expected.contains{$0>200})
    #expect(zip(expected,actual).reduce(0.0){$0+Double(abs(Int($1.0)-Int($1.1)))}/Double(expected.count)<5)
    #expect(store.document==reopened)
}
