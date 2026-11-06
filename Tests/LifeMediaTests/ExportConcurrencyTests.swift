import Testing
@preconcurrency import AVFoundation
import LifeCore
@testable import LifeMedia
@MainActor private final class ExportOverlap {
    var active=Set<Int>(),maximum=0,beats=0
    var cancellation:Task<Void,any Error>?
    func progress(_ value:Double,index:Int){if value>0 && value<1{active.insert(index);maximum=max(maximum,active.count)}}
}
@MainActor private func runConcurrentExport(index:Int,directory:URL,snapshot:ProjectSnapshot,state:ExportOverlap)async throws->URL{
    let url=directory.appendingPathComponent("result-\(index).mp4")
    try await MediaPipeline().export(snapshot,to:url){state.progress($0,index:index)}
    state.active.remove(index);return url
}
@MainActor @Test(.enabled(if:ProcessInfo.processInfo.environment["LIFE_RUN_MEDIA_INTEGRATION"]=="1"))
func concurrentNativeExportsKeepExecutorResponsiveAndProtectCancelledDestination()async throws{
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent("life-export-stress-"+UUID().uuidString);try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:directory)}
    let tone=directory.appendingPathComponent("tone.wav"),format=AVAudioFormat(standardFormatWithSampleRate:48000,channels:2)!,buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:96000)!
    buffer.frameLength=96000
    for i in 0..<96000{let value=Float(sin(Double(i)*2 * .pi*440/48000))*0.1;buffer.floatChannelData![0][i]=value;buffer.floatChannelData![1][i]=value}
    do{let file=try AVAudioFile(forWriting:tone,settings:format.settings);try file.write(from:buffer)}
    let asset=MediaAsset(url:tone,kind:.audio,duration:.init(value:2,timescale:1)),sound=Clip(assetID:asset.id,duration:asset.duration)
    let graphic=Clip(duration:asset.duration,graphic:.shape(.init(kind:.rectangle,rect:.init(x:0,y:0,width:1,height:1),fill:.init(red:1,green:0,blue:0),strokeWidth:0)))
    var document=ProjectDocument(sequence:Sequence(settings:ProjectSettings(width:64,height:64),tracks:[Track(name:"Video",kind:.shape,clips:[graphic]),Track(name:"Sound",kind:.audio,clips:[sound])]),assets:[asset])
    document=try AdjustmentLayers.adding(at:.zero,duration:asset.duration,in:document);document.sequence.tracks[2].clips[0].effects=[EffectInstance(stableID:"life.filter.grayscale",strength:0.5)]
    let snapshot=ProjectSnapshot(document:document),state=ExportOverlap()
    let heartbeat=Task{while !Task.isCancelled{do{try await Task.sleep(for:.milliseconds(5))}catch{return};if !state.active.isEmpty{state.beats+=1}}}
    defer{heartbeat.cancel()}
    try await withThrowingTaskGroup(of:URL.self){group in
        for index in 0..<12{group.addTask{
            try await runConcurrentExport(index:index,directory:directory,snapshot:snapshot,state:state)
        }}
        for try await url in group{
            let output=AVURLAsset(url:url);#expect(try await output.loadTracks(withMediaType:.video).count==1);#expect(try await output.loadTracks(withMediaType:.audio).count==1)
            let image=try await AVAssetImageGenerator(asset:output).image(at:CMTime(value:1,timescale:2)).image;#expect(image.width==64 && image.height==64)
        }
    }
    #expect(state.maximum>=2);#expect(state.beats>=2)
    let destination=directory.appendingPathComponent("existing.mp4"),original=Data("keep existing bytes".utf8);try original.write(to:destination)
    state.cancellation=Task{try await MediaPipeline().export(snapshot,to:destination){if $0>0{state.cancellation?.cancel()}}}
    do{try await state.cancellation!.value;Issue.record("Cancellation succeeded unexpectedly")}catch is CancellationError{}
    #expect(try Data(contentsOf:destination)==original)
    #expect(try FileManager.default.contentsOfDirectory(atPath:directory.path).allSatisfy{!$0.hasPrefix(".life-export-")})
}

@MainActor @Test(.enabled(if:ProcessInfo.processInfo.environment["LIFE_RUN_MEDIA_INTEGRATION"]=="1"))
func unwritableNativeExportPreservesDestinationAndProjectAndLeavesNoTemporaryFile()async throws {
    let files=FileManager.default
    let directory=files.temporaryDirectory.appendingPathComponent("life-export-denied-"+UUID().uuidString)
    try files.createDirectory(at:directory,withIntermediateDirectories:true)
    defer{
        try? files.setAttributes([.posixPermissions:0o700],ofItemAtPath:directory.path)
        try? files.removeItem(at:directory)
    }
    let destination=directory.appendingPathComponent("existing.mp4"),original=Data("preserve existing delivery".utf8)
    try original.write(to:destination)
    let clip=Clip(duration:.init(value:1,timescale:1),graphic:.shape(.init(kind:.rectangle,rect:.init(x:0,y:0,width:1,height:1),fill:.init(red:1,green:0,blue:0),strokeWidth:0)))
    let document=ProjectDocument(sequence:.init(settings:.init(width:64,height:64),tracks:[.init(name:"Picture",kind:.shape,clips:[clip])]))
    let snapshot=ProjectSnapshot(document:document),projectBytes=try document.encoded()
    try files.setAttributes([.posixPermissions:0o555],ofItemAtPath:directory.path)
    // Prove this process cannot write here, rather than assuming chmod constrains
    // a root test runner or a filesystem with different permission semantics.
    let probe=directory.appendingPathComponent("permission-probe")
    var denied=false
    do{try Data("probe".utf8).write(to:probe)}catch{denied=true}
    try #require(denied,"The test needs a destination this process cannot write.")
    var exportFailed=false
    do{try await MediaPipeline().export(snapshot,to:destination)}catch{exportFailed=true}
    #expect(exportFailed)
    #expect(try Data(contentsOf:destination)==original)
    #expect(try snapshot.document.encoded()==projectBytes)
    #expect(try files.contentsOfDirectory(atPath:directory.path)==["existing.mp4"])
}
