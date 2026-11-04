import Foundation

/// Blocking media calls run on a dispatch worker, never on Swift's cooperative executor.
/// Callers await each operation, so a stream has at most one queued operation.
/// Apple: https://developer.apple.com/videos/play/wwdc2022/110350/
final class BlockingIOWorker:Sendable {
    private let queue:DispatchQueue
    init(label:String){queue=DispatchQueue(label:label,qos:.userInitiated)}
    /// Cleanup is enqueued without consulting Task cancellation. A caller may
    /// release native resources only after this asynchronous fence completes.
    func fence()async {
        await withCheckedContinuation{(continuation:CheckedContinuation<Void,Never>) in
            queue.async{continuation.resume()}
        }
    }
    func enqueue(_ operation:@escaping @Sendable ()->Void){queue.async(execute:operation)}
    func run<Value:Sendable>(_ operation:@escaping @Sendable ()throws->Value)async throws->Value{
        try Task.checkCancellation()
        let value:Value=try await withCheckedThrowingContinuation{continuation in
            queue.async{
                do{continuation.resume(returning:try operation())}
                catch{continuation.resume(throwing:error)}
            }
        }
        try Task.checkCancellation();return value
    }
}

/// One native reader owns one queue for startup, every output pull and native
/// cancellation. Setting the flag is immediate; cancel itself waits behind any
/// in-flight native operation. No synchronous wait touches the main actor.
final class NativeReaderLifecycle:@unchecked Sendable {
    private let worker:BlockingIOWorker
    private let lock=NSLock()
    private var cancelled=false
    private let nativeCancel:@Sendable ()->Void
    init(label:String,nativeCancel:@escaping @Sendable ()->Void){
        worker=BlockingIOWorker(label:label);self.nativeCancel=nativeCancel
    }
    func checkCancellation()throws{if lock.withLock({cancelled}){throw CancellationError()}}
    func perform<Value:Sendable>(_ operation:@escaping @Sendable ()throws->Value)async throws->Value {
        try checkCancellation()
        let value=try await worker.run{[self] in
            try checkCancellation()
            return try operation()
        }
        try checkCancellation()
        return value
    }
    func cancel(){
        lock.withLock{cancelled=true}
        // Do not read native status on the requesting thread. In particular,
        // startup may still be running and must finish before native cancel.
        worker.enqueue{[self] in nativeCancel()}
    }
    func cancelAndWait()async {
        cancel()
        await worker.fence()
    }
}

/// Four exports may progress concurrently; admission suspends tasks without blocking a thread.
actor ExportAdmission {
    static let shared=ExportAdmission()
    private var active=0
    private var queue:[UUID]=[]
    private var waiting:[UUID:CheckedContinuation<Void,any Error>]=[:]
    func acquire()async throws{
        try Task.checkCancellation()
        if active<4{active+=1;return}
        guard waiting.count<32 else{throw MediaError.exportUnavailable};let id=UUID()
        try await withTaskCancellationHandler{try await withCheckedThrowingContinuation{(continuation:CheckedContinuation<Void,any Error>) in queue.append(id);waiting[id]=continuation}}onCancel:{Task{await self.cancel(id)}}
    }
    private func cancel(_ id:UUID){queue.removeAll{$0==id};waiting.removeValue(forKey:id)?.resume(throwing:CancellationError())}
    func release(){while !queue.isEmpty{let id=queue.removeFirst();if let continuation=waiting.removeValue(forKey:id){continuation.resume();return}};active-=1}
}
