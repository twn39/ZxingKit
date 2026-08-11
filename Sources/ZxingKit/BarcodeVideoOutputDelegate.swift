import Foundation
import AVFoundation
import CoreGraphics
import CoreMedia

/// An `AVCaptureVideoDataOutputSampleBufferDelegate` that scans incoming camera frames for barcodes.
///
/// It utilizes ``CameraFrameScanner`` under the hood to ensure zero-copy processing and automatic backpressure frame-dropping.
/// Results can be consumed either via the ``onResults`` closure or the asynchronous ``resultsStream``.
public final class BarcodeVideoOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    /// The underlying camera frame scanner.
    public let frameScanner: CameraFrameScanner

    /// Optional Region of Interest (ROI) bounding box (normalized `0.0...1.0` or pixel coordinates).
    public var roi: CGRect?

    /// Closure callback invoked when non-empty barcode results are detected.
    public var onResults: (([BarcodeResult]) -> Void)?

    /// Closure callback invoked if scanning encounters an error.
    public var onError: ((Error) -> Void)?

    private var streamContinuation: AsyncStream<[BarcodeResult]>.Continuation?

    /// An `AsyncStream` emitting detected barcode results asynchronously.
    public lazy private(set) var resultsStream: AsyncStream<[BarcodeResult]> = {
        AsyncStream { continuation in
            self.streamContinuation = continuation
        }
    }()

    /// Initializes a new `BarcodeVideoOutputDelegate`.
    /// - Parameters:
    ///   - scanner: The `BarcodeScanner` instance to use. Defaults to a default scanner.
    ///   - roi: Optional Region of Interest (ROI) rectangle.
    public init(scanner: BarcodeScanner = BarcodeScanner(), roi: CGRect? = nil) {
        self.frameScanner = CameraFrameScanner(scanner: scanner)
        self.roi = roi
        super.init()
    }

    /// Handles incoming camera sample buffers from AVFoundation.
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameScanner.processFrame(sampleBuffer, roi: roi) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let results):
                if !results.isEmpty {
                    self.onResults?(results)
                    self.streamContinuation?.yield(results)
                }
            case .failure(let error):
                self.onError?(error)
            }
        }
    }
}
