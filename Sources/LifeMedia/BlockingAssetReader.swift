import Foundation
@preconcurrency import AVFoundation

/// Reader samples are transferred to one consumer without mutation.
struct ReaderSample:@unchecked Sendable{let buffer:CMSampleBuffer?}
/// Startup, pulls and cancellation share one native queue. Cancellation marks
/// the session immediately, then waits for any in-flight native call to unwind.
final class BlockingAssetReader:@unchecked Sendable {
    private let reader:AVAssetReader
    private let output:AVAssetReaderOutput
    private let lifecycle:NativeReaderLifecycle
    init(reader:AVAssetReader,output:AVAssetReaderOutput,label:String){
        self.reader=reader;self.output=output
        lifecycle=NativeReaderLifecycle(label:label){[reader] in
            if reader.status == .reading{reader.cancelReading()}
        }
    }
    func start()async throws{
        try await lifecycle.perform{[self] in
            guard reader.startReading() else{throw reader.error ?? MediaError.exportUnavailable}
        }
    }
    func next()async throws->ReaderSample{
        try await lifecycle.perform{[self] in ReaderSample(buffer:output.copyNextSampleBuffer())}
    }
    func requireCompleted()async throws{
        try await lifecycle.perform{[self] in
            guard reader.status == .completed else{throw reader.error ?? MediaError.exportUnavailable}
        }
    }
    func cancel(){lifecycle.cancel()}
    func cancelAndWait()async{await lifecycle.cancelAndWait()}
}
