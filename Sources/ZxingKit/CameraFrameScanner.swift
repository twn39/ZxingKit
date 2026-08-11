import Foundation
import CoreMedia
import CoreGraphics
import os

/// A high-performance, thread-safe camera frame scanner supporting backpressure frame-dropping.
///
/// It ensures that only the latest video frame is processed while extra frames are dropped if the scanner is busy.
public final class CameraFrameScanner: Sendable {
    /// The underlying barcode scanner.
    public let scanner: BarcodeScanner
    private let isProcessing = AtomicFlag()

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
    public func processFrame(_ sampleBuffer: CMSampleBuffer, roi: CGRect? = nil, completion: @escaping @Sendable (Result<[BarcodeResult], Error>) -> Void) -> Bool {
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

/// A thread-safe, non-blocking atomic flag for backpressure detection.
private final class AtomicFlag: @unchecked Sendable {
    private let lockPointer: UnsafeMutablePointer<os_unfair_lock_s>
    private let statePointer: UnsafeMutablePointer<Bool>

    init() {
        let lock = UnsafeMutablePointer<os_unfair_lock_s>.allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock_s())
        let state = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        state.initialize(to: false)
        self.lockPointer = lock
        self.statePointer = state
    }

    deinit {
        lockPointer.deallocate()
        statePointer.deallocate()
    }

    func tryLock() -> Bool {
        os_unfair_lock_lock(lockPointer)
        defer { os_unfair_lock_unlock(lockPointer) }
        if statePointer.pointee {
            return false
        }
        statePointer.pointee = true
        return true
    }

    func unlock() {
        os_unfair_lock_lock(lockPointer)
        statePointer.pointee = false
        os_unfair_lock_unlock(lockPointer)
    }
}
