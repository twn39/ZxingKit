import Foundation
import CoreGraphics
import ZXingCpp

/// A highly-optimized, thread-safe barcode generator leveraging zxing-cpp and libzint.
public struct BarcodeGenerator: Sendable {
    public let format: BarcodeFormat
    public let width: Int
    public let height: Int
    public let margin: Int
    public let ecLevel: Int

    public init(format: BarcodeFormat, width: Int = 0, height: Int = 0, margin: Int = -1, ecLevel: Int = -1) {
        self.format = format
        self.width = width
        self.height = height
        self.margin = margin
        self.ecLevel = ecLevel
    }

    private func createZXIWriter() -> ZXIBarcodeWriter {
        let options = ZXIWriterOptions(format: format.zxiFormat)
        if width > 0 { options.width = Int32(width) }
        if height > 0 { options.height = Int32(height) }
        if margin >= 0 { options.margin = Int32(margin) }
        if ecLevel >= 0 { options.ecLevel = Int32(ecLevel) }
        return ZXIBarcodeWriter(options: options)
    }

    public func write(string: String) throws -> CGImage? {
        let writer = createZXIWriter()
        do {
            return try writer.write(string)
        } catch {
            throw ZxingError.generationFailed(error.localizedDescription)
        }
    }

    public func write(data: Data) throws -> CGImage? {
        let writer = createZXIWriter()
        do {
            return try writer.write(data)
        } catch {
            throw ZxingError.generationFailed(error.localizedDescription)
        }
    }

    public func writeAsync(string: String) async throws -> CGImage? {
        try await Task.detached(priority: .userInitiated) {
            try self.write(string: string)
        }.value
    }

    public func writeAsync(data: Data) async throws -> CGImage? {
        try await Task.detached(priority: .userInitiated) {
            try self.write(data: data)
        }.value
    }
}
