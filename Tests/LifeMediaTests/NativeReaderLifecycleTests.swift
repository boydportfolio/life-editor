import Foundation
import Dispatch
import Testing
@preconcurrency import AVFoundation
@testable import LifeMedia

private final class ReaderLifecycleProbe:@unchecked Sendable {
    let entered=DispatchSemaphore(value:0)
    let release=DispatchSemaphore(value:0)
    let cleanupRequested=DispatchSemaphore(value:0)
    private let lock=NSLock()
    private var events:[String]=[]
    private var active=false
    private var overlap=false
    func begin(_ phase:String){lock.withLock{active=true;events.append(phase+"begin")};entered.signal()}
    func end(_ phase:String){lock.withLock{events.append(phase+"end");active=false}}
    func cancel(){lock.withLock{overlap = overlap || active;events.append("cancel")}}
    func event(_ value:String){lock.withLock{events.append(value)}}
    var snapshot:(events:[String],overlap:Bool){lock.withLock{(events,overlap)}}
}

@Test(arguments:["start","read"])
func nativeReaderLifecycleSerializesCancelAfterInFlightNativeWorkAndFencesCancelledCleanup(_ phase:String)async throws {
    let probe=ReaderLifecycleProbe(),lifecycle=NativeReaderLifecycle(label:"life.test.reader.lifecycle",nativeCancel:{probe.cancel()})
    let signals=BlockingIOWorker(label:"life.test.reader.signals")
    let inFlight=Task {
        try await lifecycle.perform{
            probe.begin(phase)
            defer{probe.end(phase)}
            return probe.release.wait(timeout:.now()+5) == .success
        }
    }
    #expect(try await signals.run{probe.entered.wait(timeout:.now()+5) == .success})
    lifecycle.cancel()
    #expect(throws:CancellationError.self){try lifecycle.checkCancellation()}
    let rejected=Task{try await lifecycle.perform{probe.event("unexpectedread")}}
    let cleanup=Task {
        probe.cleanupRequested.signal()
        await lifecycle.cancelAndWait()
        probe.event("cleanupfinished")
    }
    cleanup.cancel()
    #expect(try await signals.run{probe.cleanupRequested.wait(timeout:.now()+5) == .success})
    // The native operation is held at the barrier. Cancellation must not enter
    // native code and cleanup must not complete while it still owns the queue.
    #expect(probe.snapshot.events==[phase+"begin"])
    probe.release.signal()
    do{_ = try await inFlight.value;Issue.record("Cancelled native operation returned successfully")}
    catch is CancellationError{}
    do{try await rejected.value;Issue.record("Read began after cancellation")}
    catch is CancellationError{}
    await cleanup.value
    let result=probe.snapshot
    #expect(!result.overlap)
    #expect(!result.events.contains("unexpectedread"))
    let end=try #require(result.events.firstIndex(of:phase+"end")),cancel=try #require(result.events.firstIndex(of:"cancel")),finished=try #require(result.events.firstIndex(of:"cleanupfinished"))
    #expect(end<cancel && cancel<finished)
}

@MainActor @Test(.enabled(if:ProcessInfo.processInfo.environment["LIFE_RUN_MEDIA_INTEGRATION"]=="1"))
func blockingAssetReaderCancelledCleanupRejectsNativeStartupAndFurtherPulls()async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent("life-blocking-reader-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    defer{try? FileManager.default.removeItem(at:root)}
    let url=root.appendingPathComponent("sound.wav"),format=try #require(AVAudioFormat(standardFormatWithSampleRate:48000,channels:1))
    let buffer=try #require(AVAudioPCMBuffer(pcmFormat:format,frameCapacity:480));buffer.frameLength=480
    for index in 0..<480{buffer.floatChannelData![0][index]=0}
    do{let file=try AVAudioFile(forWriting:url,settings:format.settings);try file.write(from:buffer)}
    let asset=AVURLAsset(url:url),track=try #require(try await asset.loadTracks(withMediaType:.audio).first)
    let reader=try AVAssetReader(asset:asset),output=AVAssetReaderTrackOutput(track:track,outputSettings:nil)
    reader.add(output)
    let blocking=BlockingAssetReader(reader:reader,output:output,label:"life.test.blocking-reader")
    blocking.cancel()
    let cleanup=Task{await blocking.cancelAndWait()};cleanup.cancel();await cleanup.value
    do{try await blocking.start();Issue.record("Cancelled reader started native reading")}
    catch is CancellationError{}
    do{_ = try await blocking.next();Issue.record("Cancelled reader pulled another native sample")}
    catch is CancellationError{}
    #expect(reader.status == .unknown)
}
