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

    // Issue #5: Replace LockProtectedState + two OS-specific classes with AdaptiveLock<VideoDelegateState>.
    private let state: AdaptiveLock<VideoDelegateState>

    /// Optional Region of Interest (ROI) bounding box (normalized `0.0...1.0` or pixel coordinates).
    public var roi: CGRect? {
        get { state.withLock { $0.roi } }
        set { state.withLock { $0.roi = newValue } }
    }

    /// Closure callback invoked when non-empty barcode results are detected.
    public var onResults: (@Sendable ([BarcodeResult]) -> Void)? {
        get { state.withLock { $0.onResults } }
        set { state.withLock { $0.onResults = newValue } }
    }

    /// Closure callback invoked if scanning encounters an error.
    public var onError: (@Sendable (Error) -> Void)? {
        get { state.withLock { $0.onError } }
        set { state.withLock { $0.onError = newValue } }
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
        self.state = AdaptiveLock(initialState: VideoDelegateState())
        let (stream, continuation) = AsyncStream.makeStream(of: [BarcodeResult].self)
        self.resultsStream = stream
        self.streamContinuation = continuation
        super.init()
        self.roi = roi
        // Issue #9: Register onTermination so that if the consumer exits for-await,
        // the stream is properly finished and does not suspend indefinitely.
        // Note: AsyncStream.Continuation is a struct (value type); [weak] is invalid.
        continuation.onTermination = { _ in
            continuation.finish()
        }
    }

    // Issue #9: deinit as second safety net — fires when the delegate is released
    // (e.g. ViewController pop) even if no Task was consuming the stream.
    deinit {
        streamContinuation.finish()
    }

    /// Handles incoming camera sample buffers from AVFoundation.
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let (currentRoi, onResults, onError) = state.withLock { ($0.roi, $0.onResults, $0.onError) }
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

// MARK: - Supporting Types

struct VideoDelegateState {
    var roi: CGRect?
    var onResults: (@Sendable ([BarcodeResult]) -> Void)?
    var onError: (@Sendable (Error) -> Void)?
}
#endif
