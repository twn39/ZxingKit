import Foundation
import CoreGraphics
import ZXingCpp

#if canImport(CoreImage)
import CoreImage
#endif

#if canImport(CoreVideo)
import CoreVideo
#endif

#if canImport(CoreMedia)
import CoreMedia
#endif

/// A highly-optimized, thread-safe (`Sendable`) barcode scanner leveraging zxing-cpp.
/// Reuses the underlying C++ decoding reader across scans for maximum throughput.
public struct BarcodeScanner: Sendable {
    /// The scanner configuration options.
    public let options: ScannerOptions
    private let reader: ZXIBarcodeReader

    /// Initializes a new `BarcodeScanner` with specified options.
    /// - Parameter options: The ``ScannerOptions`` configuration to apply.
    public init(options: ScannerOptions = ScannerOptions()) {
        self.options = options
        self.reader = Self.createZXIReader(from: options)
    }

    /// Convenience initializer configuring format filtering, tryHarder, and symbol limits.
    /// - Parameters:
    ///   - formats: Set of ``BarcodeFormat`` to filter during decoding (defaults to `[.any]`).
    ///   - tryHarder: Enables deeper analysis for blurry or degraded barcodes.
    ///   - maxNumberOfSymbols: Maximum number of barcodes to detect per image.
    public init(formats: Set<BarcodeFormat> = [.any], tryHarder: Bool = false, maxNumberOfSymbols: Int = 255) {
        var opts = ScannerOptions()
        opts.formats = formats
        opts.tryHarder = tryHarder
        opts.maxNumberOfSymbols = maxNumberOfSymbols
        self.options = opts
        self.reader = Self.createZXIReader(from: opts)
    }

    private static func createZXIReader(from options: ScannerOptions) -> ZXIBarcodeReader {
        let zxiOptions = ZXIReaderOptions()
        zxiOptions.formats = options.formats.map { NSNumber(value: $0.zxiFormat.rawValue) }
        zxiOptions.tryHarder = options.tryHarder
        zxiOptions.tryRotate = options.tryRotate
        zxiOptions.tryInvert = options.tryInvert
        zxiOptions.tryDownscale = options.tryDownscale
        zxiOptions.isPure = options.isPure
        zxiOptions.binarizer = ZXIBinarizer(rawValue: options.binarizer.rawValue) ?? .localAverage
        zxiOptions.downscaleFactor = options.downscaleFactor
        zxiOptions.downscaleThreshold = options.downscaleThreshold
        zxiOptions.minLineCount = options.minLineCount
        zxiOptions.maxNumberOfSymbols = options.maxNumberOfSymbols
        zxiOptions.returnErrors = options.returnErrors
        zxiOptions.eanAddOnSymbol = ZXIEanAddOnSymbol(rawValue: options.eanAddOnSymbol.rawValue) ?? .ignore
        zxiOptions.textMode = ZXITextMode(rawValue: options.textMode.rawValue) ?? .HRI
        return ZXIBarcodeReader(options: zxiOptions)
    }

    /// Scans a `CGImage` for barcodes.
    /// - Parameters:
    ///   - cgImage: The `CGImage` to scan.
    ///   - roi: Optional Region of Interest (ROI) bounding box (normalized `0.0...1.0` or pixel coordinates).
    /// - Returns: An array of detected ``BarcodeResult``.
    /// - Throws: Scanning errors if decoding fails.
    public func read(cgImage: CGImage, roi: CGRect? = nil) throws -> [BarcodeResult] {
        let results = try reader.read(cgImage, cropRect: roi ?? .zero)
        return results.map { BarcodeResult(from: $0) }
    }

    #if canImport(CoreImage)
    /// Scans a `CIImage` for barcodes.
    /// - Parameters:
    ///   - ciImage: The `CIImage` to scan.
    ///   - roi: Optional Region of Interest (ROI) rectangle.
    /// - Returns: An array of detected ``BarcodeResult``.
    /// - Throws: Scanning errors if decoding fails.
    public func read(ciImage: CIImage, roi: CGRect? = nil) throws -> [BarcodeResult] {
        let results = try reader.read(ciImage, cropRect: roi ?? .zero)
        return results.map { BarcodeResult(from: $0) }
    }
    #endif

    #if canImport(CoreVideo)
    /// Scans a `CVPixelBuffer` for barcodes without unnecessary copy operations.
    /// - Parameters:
    ///   - pixelBuffer: The `CVPixelBuffer` to scan.
    ///   - roi: Optional Region of Interest (ROI) rectangle.
    /// - Returns: An array of detected ``BarcodeResult``.
    /// - Throws: Scanning errors if decoding fails.
    public func read(pixelBuffer: CVPixelBuffer, roi: CGRect? = nil) throws -> [BarcodeResult] {
        let results = try reader.read(pixelBuffer, cropRect: roi ?? .zero)
        return results.map { BarcodeResult(from: $0) }
    }
    #endif

    #if canImport(CoreMedia)
    /// Scans a `CMSampleBuffer` directly for barcodes.
    /// - Parameters:
    ///   - sampleBuffer: The `CMSampleBuffer` received from AVFoundation.
    ///   - roi: Optional Region of Interest (ROI) rectangle.
    /// - Returns: An array of detected ``BarcodeResult``.
    /// - Throws: Scanning errors if decoding fails.
    public func read(sampleBuffer: CMSampleBuffer, roi: CGRect? = nil) throws -> [BarcodeResult] {
        let results = try reader.read(sampleBuffer, cropRect: roi ?? .zero)
        return results.map { BarcodeResult(from: $0) }
    }
    #endif

    /// Asynchronously scans a `CGImage` for barcodes.
    /// - Parameters:
    ///   - cgImage: The `CGImage` to scan.
    ///   - roi: Optional Region of Interest (ROI) rectangle.
    /// - Returns: An array of detected ``BarcodeResult``.
    /// - Throws: Scanning errors if decoding fails.
    public func readAsync(cgImage: CGImage, roi: CGRect? = nil) async throws -> [BarcodeResult] {
        try await Task.detached(priority: .userInitiated) {
            try self.read(cgImage: cgImage, roi: roi)
        }.value
    }

    #if canImport(CoreImage)
    /// Asynchronously scans a `CIImage` for barcodes.
    /// - Parameters:
    ///   - ciImage: The `CIImage` to scan.
    ///   - roi: Optional Region of Interest (ROI) rectangle.
    /// - Returns: An array of detected ``BarcodeResult``.
    /// - Throws: Scanning errors if decoding fails.
    public func readAsync(ciImage: CIImage, roi: CGRect? = nil) async throws -> [BarcodeResult] {
        try await Task.detached(priority: .userInitiated) {
            try self.read(ciImage: ciImage, roi: roi)
        }.value
    }
    #endif

    #if canImport(CoreVideo)
    /// Asynchronously scans a `CVPixelBuffer` for barcodes.
    /// - Parameters:
    ///   - pixelBuffer: The `CVPixelBuffer` to scan.
    ///   - roi: Optional Region of Interest (ROI) rectangle.
    /// - Returns: An array of detected ``BarcodeResult``.
    /// - Throws: Scanning errors if decoding fails.
    public func readAsync(pixelBuffer: CVPixelBuffer, roi: CGRect? = nil) async throws -> [BarcodeResult] {
        struct SendablePixelBuffer: @unchecked Sendable {
            let buffer: CVPixelBuffer
        }
        let wrapped = SendablePixelBuffer(buffer: pixelBuffer)
        return try await Task.detached(priority: .userInitiated) {
            try self.read(pixelBuffer: wrapped.buffer, roi: roi)
        }.value
    }
    #endif

    #if canImport(CoreMedia)
    /// Asynchronously scans a `CMSampleBuffer` for barcodes.
    /// - Parameters:
    ///   - sampleBuffer: The `CMSampleBuffer` to scan.
    ///   - roi: Optional Region of Interest (ROI) rectangle.
    /// - Returns: An array of detected ``BarcodeResult``.
    /// - Throws: Scanning errors if decoding fails.
    public func readAsync(sampleBuffer: CMSampleBuffer, roi: CGRect? = nil) async throws -> [BarcodeResult] {
        struct SendableSampleBuffer: @unchecked Sendable {
            let buffer: CMSampleBuffer
        }
        let wrapped = SendableSampleBuffer(buffer: sampleBuffer)
        return try await Task.detached(priority: .userInitiated) {
            try self.read(sampleBuffer: wrapped.buffer, roi: roi)
        }.value
    }
    #endif
}
