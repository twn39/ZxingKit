import Foundation
import CoreGraphics
import ZXingCpp

/// A highly-optimized, thread-safe barcode generator leveraging zxing-cpp and bundled libzint vector rendering.
public struct BarcodeGenerator: Sendable {
    /// The barcode format to generate.
    public let format: BarcodeFormat
    /// Target image width in pixels.
    public let width: Int
    /// Target image height in pixels.
    public let height: Int
    /// Quiet zone margin in module sizes (-1 for default format margin).
    public let margin: Int
    /// Error correction level (-1 for default format level).
    public let ecLevel: Int

    private let writer: ZXIBarcodeWriter

    /// Initializes a new `BarcodeGenerator`.
    /// - Parameters:
    ///   - format: The ``BarcodeFormat`` to generate.
    ///   - width: Target image width in pixels (0 for default module size).
    ///   - height: Target image height in pixels (0 for default module size).
    ///   - margin: Quiet zone margin size (-1 for format default).
    ///   - ecLevel: Error correction level (-1 for format default).
    public init(format: BarcodeFormat, width: Int = 0, height: Int = 0, margin: Int = -1, ecLevel: Int = -1) {
        self.format = format
        self.width = width
        self.height = height
        self.margin = margin
        self.ecLevel = ecLevel
        self.writer = Self.createZXIWriter(format: format, width: width, height: height, margin: margin, ecLevel: ecLevel)
    }

    private static func createZXIWriter(format: BarcodeFormat, width: Int, height: Int, margin: Int, ecLevel: Int) -> ZXIBarcodeWriter {
        let options = ZXIWriterOptions(format: format.zxiFormat)
        if width > 0 { options.width = Int32(width) }
        if height > 0 { options.height = Int32(height) }
        if margin >= 0 { options.margin = Int32(margin) }
        if ecLevel >= 0 { options.ecLevel = Int32(ecLevel) }
        return ZXIBarcodeWriter(options: options)
    }

    /// Encodes a text string into a barcode `CGImage`.
    /// - Parameter string: The string content to encode.
    /// - Returns: A `CGImage` containing the rendered barcode bitmap, or `nil` if generation fails.
    /// - Throws: ``ZxingError/generationFailed(_:)`` if encoding fails.
    public func write(string: String) throws -> CGImage? {
        do {
            return try writer.write(string)
        } catch {
            throw ZxingError.generationFailed(error.localizedDescription)
        }
    }

    /// Encodes raw binary byte data into a barcode `CGImage`.
    /// - Parameter data: The raw byte data to encode.
    /// - Returns: A `CGImage` containing the rendered barcode bitmap, or `nil` if generation fails.
    /// - Throws: ``ZxingError/generationFailed(_:)`` if encoding fails.
    public func write(data: Data) throws -> CGImage? {
        do {
            return try writer.write(data)
        } catch {
            throw ZxingError.generationFailed(error.localizedDescription)
        }
    }

    /// Asynchronously encodes a text string into a barcode `CGImage`.
    /// - Parameter string: The text string to encode.
    /// - Returns: A `CGImage` containing the rendered barcode bitmap, or `nil` if generation fails.
    /// - Throws: ``ZxingError/generationFailed(_:)`` if encoding fails.
    public func writeAsync(string: String) async throws -> CGImage? {
        try await Task.detached(priority: .userInitiated) {
            try self.write(string: string)
        }.value
    }

    /// Asynchronously encodes raw binary byte data into a barcode `CGImage`.
    /// - Parameter data: The raw byte data to encode.
    /// - Returns: A `CGImage` containing the rendered barcode bitmap, or `nil` if generation fails.
    /// - Throws: ``ZxingError/generationFailed(_:)`` if encoding fails.
    public func writeAsync(data: Data) async throws -> CGImage? {
        try await Task.detached(priority: .userInitiated) {
            try self.write(data: data)
        }.value
    }
}
