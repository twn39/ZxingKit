#if canImport(AVFoundation) && canImport(CoreMedia)
import Foundation
import AVFoundation
import CoreGraphics
import CoreMedia
import os

/// An `AVCaptureVideoDataOutputSampleBufferDelegate` that scans incoming camera frames for barcodes.
///
/// It utilizes ``CameraFrameScanner`` under the hood to ensure zero-copy processing and automatic backpressure frame-dropping.
/// Results can be consumed either via the ``onResults`` closure or the asynchronous ``resultsStream``.
public final class BarcodeVideoOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, Sendable {
    /// The underlying camera frame scanner.
    public let frameScanner: CameraFrameScanner

    private let state = LockProtectedState()

    /// Optional Region of Interest (ROI) bounding box (normalized `0.0...1.0` or pixel coordinates).
    public var roi: CGRect? {
        get { state.getRoi() }
        set { state.setRoi(newValue) }
    }

    /// Closure callback invoked when non-empty barcode results are detected.
    public var onResults: (@Sendable ([BarcodeResult]) -> Void)? {
        get { state.getOnResults() }
        set { state.setOnResults(newValue) }
    }

    /// Closure callback invoked if scanning encounters an error.
    public var onError: (@Sendable (Error) -> Void)? {
        get { state.getOnError() }
        set { state.setOnError(newValue) }
    }

    /// An `AsyncStream` emitting detected barcode results asynchronously.
    public let resultsStream: AsyncStream<[BarcodeResult]>
    private let streamContinuation: AsyncStream<[BarcodeResult]>.Continuation

    /// Initializes a new `BarcodeVideoOutputDelegate`.
    /// - Parameters:
    ///   - scanner: The `BarcodeScanner` instance to use. Defaults to a default scanner.
    ///   - roi: Optional Region of Interest (ROI) rectangle.
    public init(scanner: BarcodeScanner = BarcodeScanner(), roi: CGRect? = nil) {
        self.frameScanner = CameraFrameScanner(scanner: scanner)
        let (stream, continuation) = AsyncStream.makeStream(of: [BarcodeResult].self)
        self.resultsStream = stream
        self.streamContinuation = continuation
        super.init()
        self.roi = roi
    }

    /// Handles incoming camera sample buffers from AVFoundation.
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let (currentRoi, onResults, onError) = state.snapshot()
        frameScanner.processFrame(sampleBuffer, roi: currentRoi) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let results):
                if !results.isEmpty {
                    onResults?(results)
                    self.streamContinuation.yield(results)
                }
            case .failure(let error):
                onError?(error)
            }
        }
    }
}

private struct VideoDelegateState {
    var roi: CGRect?
    var onResults: (@Sendable ([BarcodeResult]) -> Void)?
    var onError: (@Sendable (Error) -> Void)?
}

private final class LockProtectedState: Sendable {
    private let impl: any LockProtectedStateImpl

    init() {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            self.impl = OSUnfairLockState()
        } else {
            self.impl = NSLockState()
        }
    }

    func snapshot() -> (roi: CGRect?, onResults: (@Sendable ([BarcodeResult]) -> Void)?, onError: (@Sendable (Error) -> Void)?) {
        impl.snapshot()
    }

    func getRoi() -> CGRect? { impl.getRoi() }
    func setRoi(_ roi: CGRect?) { impl.setRoi(roi) }

    func getOnResults() -> (@Sendable ([BarcodeResult]) -> Void)? { impl.getOnResults() }
    func setOnResults(_ callback: (@Sendable ([BarcodeResult]) -> Void)?) { impl.setOnResults(callback) }

    func getOnError() -> (@Sendable (Error) -> Void)? { impl.getOnError() }
    func setOnError(_ callback: (@Sendable (Error) -> Void)?) { impl.setOnError(callback) }
}

private protocol LockProtectedStateImpl: Sendable {
    func snapshot() -> (roi: CGRect?, onResults: (@Sendable ([BarcodeResult]) -> Void)?, onError: (@Sendable (Error) -> Void)?)
    func getRoi() -> CGRect?
    func setRoi(_ roi: CGRect?)
    func getOnResults() -> (@Sendable ([BarcodeResult]) -> Void)?
    func setOnResults(_ callback: (@Sendable ([BarcodeResult]) -> Void)?)
    func getOnError() -> (@Sendable (Error) -> Void)?
    func setOnError(_ callback: (@Sendable (Error) -> Void)?)
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
private final class OSUnfairLockState: LockProtectedStateImpl {
    private let lock = OSAllocatedUnfairLock(initialState: VideoDelegateState())

    func snapshot() -> (roi: CGRect?, onResults: (@Sendable ([BarcodeResult]) -> Void)?, onError: (@Sendable (Error) -> Void)?) {
        lock.withLock { ($0.roi, $0.onResults, $0.onError) }
    }

    func getRoi() -> CGRect? { lock.withLock { $0.roi } }
    func setRoi(_ roi: CGRect?) { lock.withLock { $0.roi = roi } }

    func getOnResults() -> (@Sendable ([BarcodeResult]) -> Void)? { lock.withLock { $0.onResults } }
    func setOnResults(_ callback: (@Sendable ([BarcodeResult]) -> Void)?) { lock.withLock { $0.onResults = callback } }

    func getOnError() -> (@Sendable (Error) -> Void)? { lock.withLock { $0.onError } }
    func setOnError(_ callback: (@Sendable (Error) -> Void)?) { lock.withLock { $0.onError = callback } }
}

private final class NSLockState: LockProtectedStateImpl {
    private let lock = NSLock()
    private final class Storage: @unchecked Sendable {
        var state = VideoDelegateState()
    }
    private let storage = Storage()

    func snapshot() -> (roi: CGRect?, onResults: (@Sendable ([BarcodeResult]) -> Void)?, onError: (@Sendable (Error) -> Void)?) {
        lock.lock()
        defer { lock.unlock() }
        return (storage.state.roi, storage.state.onResults, storage.state.onError)
    }

    func getRoi() -> CGRect? {
        lock.lock()
        defer { lock.unlock() }
        return storage.state.roi
    }

    func setRoi(_ roi: CGRect?) {
        lock.lock()
        storage.state.roi = roi
        lock.unlock()
    }

    func getOnResults() -> (@Sendable ([BarcodeResult]) -> Void)? {
        lock.lock()
        defer { lock.unlock() }
        return storage.state.onResults
    }

    func setOnResults(_ callback: (@Sendable ([BarcodeResult]) -> Void)?) {
        lock.lock()
        storage.state.onResults = callback
        lock.unlock()
    }

    func getOnError() -> (@Sendable (Error) -> Void)? {
        lock.lock()
        defer { lock.unlock() }
        return storage.state.onError
    }

    func setOnError(_ callback: (@Sendable (Error) -> Void)?) {
        lock.lock()
        storage.state.onError = callback
        lock.unlock()
    }
}
#endif
