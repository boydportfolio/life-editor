import Foundation
import Darwin

/// Opt-in diagnostic records contain identifiers and native state only, never
/// media URLs, payloads or timestamps from the recording. Each JSON line is sent
/// directly to the file descriptor before returning to the native call site.
struct NativeReaderTraceRecord:Codable,Sendable {
    let jobID:UUID
    let readerID:UUID
    let monotonicNanoseconds:UInt64
    let threadID:UInt64
    let event:String
    let streamKind:String?
    let streamIndex:Int?
    let sampleOrdinal:Int?
    let readerStatus:Int?
    let hasSample:Bool?
    let succeeded:Bool?
    let activeExports:Int
    let serialPulls:Bool
}

final class NativeReaderTrace:@unchecked Sendable {
    static let configured:NativeReaderTrace? = {
        guard let path=ProcessInfo.processInfo.environment["LIFE_NATIVE_READER_TRACE"],!path.isEmpty else{return nil}
        return NativeReaderTrace(url:URL(fileURLWithPath:path))
    }()
    private let lock=NSLock()
    private var descriptor:Int32
    init?(url:URL){
        guard url.isFileURL else{return nil}
        let descriptor=url.withUnsafeFileSystemRepresentation{path in
            guard let path else{return Int32(-1)}
            return Darwin.open(path,O_WRONLY|O_CREAT|O_APPEND|O_CLOEXEC|O_NOFOLLOW,mode_t(0o600))
        }
        guard descriptor>=0 else{return nil}
        self.descriptor=descriptor
    }
    deinit{if descriptor>=0{Darwin.close(descriptor)}}
    func record(jobID:UUID,readerID:UUID,event:String,streamKind:String?=nil,streamIndex:Int?=nil,
                sampleOrdinal:Int?=nil,readerStatus:Int?=nil,hasSample:Bool?=nil,succeeded:Bool?=nil,
                activeExports:Int,serialPulls:Bool){
        lock.withLock{
            guard descriptor>=0 else{return}
            var threadID:UInt64=0
            pthread_threadid_np(nil,&threadID)
            let record=NativeReaderTraceRecord(jobID:jobID,readerID:readerID,
                monotonicNanoseconds:DispatchTime.now().uptimeNanoseconds,threadID:threadID,event:event,
                streamKind:streamKind,streamIndex:streamIndex,sampleOrdinal:sampleOrdinal,
                readerStatus:readerStatus,hasSample:hasSample,succeeded:succeeded,
                activeExports:activeExports,serialPulls:serialPulls)
            guard var data=try? JSONEncoder().encode(record) else{return}
            data.append(0x0a)
            let written=data.withUnsafeBytes{bytes->Bool in
                guard let base=bytes.baseAddress else{return true}
                var offset=0
                while offset<bytes.count {
                    let count=Darwin.write(descriptor,base.advanced(by:offset),bytes.count-offset)
                    if count<0,errno==EINTR{continue}
                    guard count>0 else{return false}
                    offset+=count
                }
                return true
            }
            // A full disk or inaccessible destination must not affect export.
            // Disable this sink after failure rather than repeatedly retrying it.
            if !written{Darwin.close(descriptor);descriptor = -1}
        }
    }
}

/// Counts admitted export jobs only while diagnostic tracing is enabled.
private enum NativeReaderDiagnosticActivity {
    static let lock=NSLock()
    nonisolated(unsafe) static var active=0
    static func begin(){lock.withLock{active+=1}}
    static func end(){lock.withLock{active-=1}}
    static var count:Int{lock.withLock{active}}
}

final class NativeReaderDiagnostics:@unchecked Sendable {
    let jobID=UUID()
    let readerID=UUID()
    let serialPulls:Bool
    private let trace:NativeReaderTrace?
    private let lifecycleLock=NSLock()
    private var finished=false
    init(trace:NativeReaderTrace? = .configured,serialPulls:Bool=true){
        self.trace=trace;self.serialPulls=serialPulls
        if trace != nil{NativeReaderDiagnosticActivity.begin()}
    }
    deinit{finish()}
    func finish(){
        lifecycleLock.withLock{
            guard !finished else{return};finished=true
            if trace != nil{NativeReaderDiagnosticActivity.end()}
        }
    }
    var isTracing:Bool{trace != nil}
    func status(_ value:@autoclosure ()->Int)->Int? {
        guard trace != nil else{return nil}
        return value()
    }
    func record(_ event:String,streamKind:String?=nil,streamIndex:Int?=nil,sampleOrdinal:Int?=nil,
                readerStatus:Int?=nil,hasSample:Bool?=nil,succeeded:Bool?=nil){
        trace?.record(jobID:jobID,readerID:readerID,event:event,streamKind:streamKind,
            streamIndex:streamIndex,sampleOrdinal:sampleOrdinal,readerStatus:readerStatus,
            hasSample:hasSample,succeeded:succeeded,activeExports:NativeReaderDiagnosticActivity.count,serialPulls:serialPulls)
    }
}
