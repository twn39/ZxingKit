#if canImport(AVFoundation) && canImport(CoreMedia)
import Foundation
import AVFoundation
import CoreMedia
import CoreGraphics
import os

/// A high-performance, thread-safe camera frame scanner supporting backpressure frame-dropping.
///
/// It ensures that only the latest video frame is processed while extra frames are dropped if the scanner is busy.
public final class CameraFrameScanner: Sendable {
    /// The underlying barcode scanner.
    public let scanner: BarcodeScanner
    // Issue #5: Replace AtomicFlag + two OS-specific classes with AdaptiveLock<Bool>.
    private let isProcessing: AdaptiveLock<Bool>

    /// Initializes a new `CameraFrameScanner`.
    /// - Parameter scanner: The `BarcodeScanner` instance to use. Defaults to a default scanner.
    public init(scanner: BarcodeScanner = BarcodeScanner()) {
        self.scanner = scanner
        self.isProcessing = AdaptiveLock(initialState: false)
    }

    /// Process an incoming camera video frame (`CMSampleBuffer`).
    /// - Parameters:
    ///   - sampleBuffer: The `CMSampleBuffer` received from `AVCaptureVideoDataOutputSampleBufferDelegate`.
    ///   - roi: Optional Region of Interest (ROI) bounding box (normalized `0.0...1.0` or pixel coordinates).
    ///   - completion: Callback executed when scanning completes.
    /// - Returns: `true` if the frame was accepted for scanning; `false` if dropped due to backpressure.
    @discardableResult
    public func processFrame(_ sampleBuffer: CMSampleBuffer, roi: CGRect? = nil, completion: @escaping @Sendable (Result<[BarcodeResult], Error>) -> Void) -> Bool {
        // Atomically check-and-set the processing flag.
        let acquired = isProcessing.withLock { flag -> Bool in
            guard !flag else { return false }
            flag = true
            return true
        }
        guard acquired else { return false } // Frame dropped due to backpressure

        // CMSampleBuffer is a CF/ObjC type without Sendable conformance — wrap it.
        struct Wrapper: @unchecked Sendable { let value: CMSampleBuffer }
        let wrapped = Wrapper(value: sampleBuffer)

        Task.detached(priority: .userInitiated) {
            defer { self.isProcessing.withLock { $0 = false } }
            do {
                let results = try self.scanner.read(sampleBuffer: wrapped.value, roi: roi)
                completion(.success(results))
            } catch {
                completion(.failure(error))
            }
        }
        return true
    }

    /// Process an incoming camera video frame asynchronously.
    /// - Parameters:
    ///   - sampleBuffer: The `CMSampleBuffer` to process.
    ///   - roi: Optional Region of Interest (ROI) rectangle.
    /// - Returns: The array of detected ``BarcodeResult``, or `nil` if the frame was dropped.
    public func processFrameAsync(_ sampleBuffer: CMSampleBuffer, roi: CGRect? = nil) async throws -> [BarcodeResult]? {
        let acquired = isProcessing.withLock { flag -> Bool in
            guard !flag else { return false }
            flag = true
            return true
        }
        guard acquired else { return nil } // Frame dropped due to backpressure
        defer { isProcessing.withLock { $0 = false } }

        return try await scanner.readAsync(sampleBuffer: sampleBuffer, roi: roi)
    }
}
#endif
