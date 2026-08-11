import Foundation
import CoreMedia
import CoreGraphics
import os

/// A high-performance, thread-safe camera frame scanner supporting backpressure frame-dropping.
///
/// It ensures that only the latest video frame is processed while extra frames are dropped if the scanner is busy.
public final class CameraFrameScanner: @unchecked Sendable {
    /// The underlying barcode scanner.
    public let scanner: BarcodeScanner
    private let isProcessing = AtomicBool()

    /// Initializes a new `CameraFrameScanner`.
    /// - Parameter scanner: The `BarcodeScanner` instance to use. Defaults to a default scanner.
    public init(scanner: BarcodeScanner = BarcodeScanner()) {
        self.scanner = scanner
    }

    /// Process an incoming camera video frame (`CMSampleBuffer`).
    /// - Parameters:
    ///   - sampleBuffer: The `CMSampleBuffer` received from `AVCaptureVideoDataOutputSampleBufferDelegate`.
    ///   - roi: Optional Region of Interest (ROI) bounding box (normalized `0.0...1.0` or pixel coordinates).
    ///   - completion: Callback executed when scanning completes.
    /// - Returns: `true` if the frame was accepted for scanning; `false` if dropped due to backpressure.
    @discardableResult
    public func processFrame(_ sampleBuffer: CMSampleBuffer, roi: CGRect? = nil, completion: @escaping (Result<[BarcodeResult], Error>) -> Void) -> Bool {
        guard isProcessing.tryLock() else {
            return false // Frame dropped due to backpressure
        }

        Task.detached(priority: .userInitiated) {
            defer { self.isProcessing.unlock() }
            do {
                let results = try self.scanner.read(sampleBuffer: sampleBuffer, roi: roi)
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
        guard isProcessing.tryLock() else {
            return nil // Frame dropped due to backpressure
        }
        defer { isProcessing.unlock() }

        return try await scanner.readAsync(sampleBuffer: sampleBuffer, roi: roi)
    }
}

private final class AtomicBool: @unchecked Sendable {
    private var lock = os_unfair_lock()
    private var flag = false

    func tryLock() -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        if flag { return false }
        flag = true
        return true
    }

    func unlock() {
        os_unfair_lock_lock(&lock)
        flag = false
        os_unfair_lock_unlock(&lock)
    }
}
