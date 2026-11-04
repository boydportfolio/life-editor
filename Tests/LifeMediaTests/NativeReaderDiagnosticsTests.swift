import Foundation
import Dispatch
import Testing
@testable import LifeMedia

@Test func nativeReaderDiagnosticTraceWritesCompleteConcurrentJSONLinesWithoutMediaData()throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent("life-reader-trace-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    defer{try? FileManager.default.removeItem(at:root)}
    let url=root.appendingPathComponent("reader.jsonl"),trace=try #require(NativeReaderTrace(url:url))
    let job=NativeReaderDiagnostics(trace:trace,serialPulls:false)
    DispatchQueue.concurrentPerform(iterations:100){ordinal in
        job.record("samplebegin",streamKind:ordinal%2==0 ? "video":"audio",streamIndex:ordinal%2,sampleOrdinal:ordinal,readerStatus:1)
        job.record("sampleend",streamKind:ordinal%2==0 ? "video":"audio",streamIndex:ordinal%2,sampleOrdinal:ordinal,readerStatus:1,hasSample:true)
    }
    job.finish();job.finish()
    // Read while the sink remains open: no userspace buffer needs flushing.
    let bytes=try Data(contentsOf:url),lines=bytes.split(separator:0x0a)
    #expect(lines.count==200 && bytes.last==0x0a)
    let records=try lines.map{try JSONDecoder().decode(NativeReaderTraceRecord.self,from:Data($0))}
    #expect(Set(records.map(\.jobID))==[job.jobID])
    #expect(Set(records.map(\.readerID))==[job.readerID])
    #expect(records.allSatisfy{$0.threadID>0 && $0.monotonicNanoseconds>0 && $0.activeExports>=1 && !$0.serialPulls})
    #expect(zip(records,records.dropFirst()).allSatisfy{$0.monotonicNanoseconds <= $1.monotonicNanoseconds})
    for ordinal in 0..<100 {
        #expect(records.filter{$0.sampleOrdinal==ordinal}.map(\.event)==["samplebegin","sampleend"])
    }
    let text=String(decoding:bytes,as:UTF8.self)
    #expect(!text.contains(root.path) && !text.contains("mediaURL"))
}

@Test func nativeReaderDiagnosticInvalidDestinationAndDisabledTraceAreHarmless(){
    let missing=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("trace.jsonl")
    #expect(NativeReaderTrace(url:missing)==nil)
    let disabled=NativeReaderDiagnostics(trace:nil,serialPulls:true)
    var evaluated=false
    #expect(disabled.status({evaluated=true;return 1}())==nil)
    #expect(!evaluated)
    disabled.record("samplebegin",streamKind:"video",streamIndex:0,sampleOrdinal:0)
    disabled.finish()
}
