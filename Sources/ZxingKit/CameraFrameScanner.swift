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

        struct SendableSampleBuffer: @unchecked Sendable {
            let buffer: CMSampleBuffer
        }
        let wrapped = SendableSampleBuffer(buffer: sampleBuffer)

        Task.detached(priority: .userInitiated) {
            defer { self.isProcessing.unlock() }
            do {
                let results = try self.scanner.read(sampleBuffer: wrapped.buffer, roi: roi)
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
final class AtomicFlag: Sendable {
    private let impl: any AtomicFlagImpl

    init() {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            self.impl = OSUnfairAtomicFlag()
        } else {
            self.impl = NSLockAtomicFlag()
        }
    }

    func tryLock() -> Bool {
        impl.tryLock()
    }

    func unlock() {
        impl.unlock()
    }
}

protocol AtomicFlagImpl: Sendable {
    func tryLock() -> Bool
    func unlock()
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
final class OSUnfairAtomicFlag: AtomicFlagImpl {
    private struct State {
        var isProcessing = false
    }
    private let lock = OSAllocatedUnfairLock(initialState: State())

    func tryLock() -> Bool {
        lock.withLock { state in
            if state.isProcessing {
                return false
            }
            state.isProcessing = true
            return true
        }
    }

    func unlock() {
        lock.withLock { state in
            state.isProcessing = false
        }
    }
}

final class NSLockAtomicFlag: AtomicFlagImpl {
    private let lock = NSLock()
    private final class Storage: @unchecked Sendable {
        var isProcessing = false
    }
    private let storage = Storage()

    func tryLock() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if storage.isProcessing {
            return false
        }
        storage.isProcessing = true
        return true
    }

    func unlock() {
        lock.lock()
        storage.isProcessing = false
        lock.unlock()
    }
}
#endif
