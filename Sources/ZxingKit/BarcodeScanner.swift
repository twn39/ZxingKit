import Foundation
import CoreGraphics
import CoreImage
import CoreVideo
import CoreMedia
import ZXingCpp

extension ZXIBarcodeReader: @retroactive @unchecked Sendable {}

/// A highly-optimized barcode scanner leveraging zxing-cpp.
/// This type is entirely thread-safe (`Sendable`) and reuses the underlying engine reader across scans.
public struct BarcodeScanner: Sendable {
    public let options: ScannerOptions
    private let reader: ZXIBarcodeReader

    public init(options: ScannerOptions = ScannerOptions()) {
        self.options = options
        self.reader = Self.createZXIReader(from: options)
    }

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

    public func read(cgImage: CGImage, roi: CGRect? = nil) throws -> [BarcodeResult] {
        let results = try reader.read(cgImage, cropRect: roi ?? .zero)
        return results.map { BarcodeResult(from: $0) }
    }

    public func read(ciImage: CIImage, roi: CGRect? = nil) throws -> [BarcodeResult] {
        let results = try reader.read(ciImage, cropRect: roi ?? .zero)
        return results.map { BarcodeResult(from: $0) }
    }

    public func read(pixelBuffer: CVPixelBuffer, roi: CGRect? = nil) throws -> [BarcodeResult] {
        let results = try reader.read(pixelBuffer, cropRect: roi ?? .zero)
        return results.map { BarcodeResult(from: $0) }
    }

    public func read(sampleBuffer: CMSampleBuffer, roi: CGRect? = nil) throws -> [BarcodeResult] {
        let results = try reader.read(sampleBuffer, cropRect: roi ?? .zero)
        return results.map { BarcodeResult(from: $0) }
    }

    // Async/Await support for concurrent processing
    public func readAsync(cgImage: CGImage, roi: CGRect? = nil) async throws -> [BarcodeResult] {
        try await Task.detached(priority: .userInitiated) {
            try self.read(cgImage: cgImage, roi: roi)
        }.value
    }

    public func readAsync(ciImage: CIImage, roi: CGRect? = nil) async throws -> [BarcodeResult] {
        try await Task.detached(priority: .userInitiated) {
            try self.read(ciImage: ciImage, roi: roi)
        }.value
    }

    public func readAsync(pixelBuffer: CVPixelBuffer, roi: CGRect? = nil) async throws -> [BarcodeResult] {
        try await Task.detached(priority: .userInitiated) {
            try self.read(pixelBuffer: pixelBuffer, roi: roi)
        }.value
    }

    public func readAsync(sampleBuffer: CMSampleBuffer, roi: CGRect? = nil) async throws -> [BarcodeResult] {
        try await Task.detached(priority: .userInitiated) {
            try self.read(sampleBuffer: sampleBuffer, roi: roi)
        }.value
    }
}
