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
        let currentRoi = self.roi
        frameScanner.processFrame(sampleBuffer, roi: currentRoi) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let results):
                if !results.isEmpty {
                    self.onResults?(results)
                    self.streamContinuation.yield(results)
                }
            case .failure(let error):
                self.onError?(error)
            }
        }
    }
}

private final class LockProtectedState: @unchecked Sendable {
    private struct MutableState {
        var roi: CGRect?
        var onResults: (@Sendable ([BarcodeResult]) -> Void)?
        var onError: (@Sendable (Error) -> Void)?
    }

    private let lockPointer: UnsafeMutablePointer<os_unfair_lock_s>
    private let statePointer: UnsafeMutablePointer<MutableState>

    init() {
        let lock = UnsafeMutablePointer<os_unfair_lock_s>.allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock_s())
        let state = UnsafeMutablePointer<MutableState>.allocate(capacity: 1)
        state.initialize(to: MutableState())
        self.lockPointer = lock
        self.statePointer = state
    }

    deinit {
        lockPointer.deallocate()
        statePointer.deallocate()
    }

    func getRoi() -> CGRect? {
        os_unfair_lock_lock(lockPointer)
        defer { os_unfair_lock_unlock(lockPointer) }
        return statePointer.pointee.roi
    }

    func setRoi(_ roi: CGRect?) {
        os_unfair_lock_lock(lockPointer)
        defer { os_unfair_lock_unlock(lockPointer) }
        statePointer.pointee.roi = roi
    }

    func getOnResults() -> (@Sendable ([BarcodeResult]) -> Void)? {
        os_unfair_lock_lock(lockPointer)
        defer { os_unfair_lock_unlock(lockPointer) }
        return statePointer.pointee.onResults
    }

    func setOnResults(_ callback: (@Sendable ([BarcodeResult]) -> Void)?) {
        os_unfair_lock_lock(lockPointer)
        defer { os_unfair_lock_unlock(lockPointer) }
        statePointer.pointee.onResults = callback
    }

    func getOnError() -> (@Sendable (Error) -> Void)? {
        os_unfair_lock_lock(lockPointer)
        defer { os_unfair_lock_unlock(lockPointer) }
        return statePointer.pointee.onError
    }

    func setOnError(_ callback: (@Sendable (Error) -> Void)?) {
        os_unfair_lock_lock(lockPointer)
        defer { os_unfair_lock_unlock(lockPointer) }
        statePointer.pointee.onError = callback
    }
}
