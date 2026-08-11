import Foundation
import CoreGraphics
import CoreImage
import CoreVideo
import ZXingCpp

/// A highly-optimized barcode scanner leveraging zxing-cpp.
/// This type is entirely thread-safe (`Sendable`) and supports both synchronous and concurrent scanning.
public struct BarcodeScanner: Sendable {
    private let options: ScannerOptions

    public init(options: ScannerOptions = ScannerOptions()) {
        self.options = options
    }

    public init(formats: Set<BarcodeFormat> = [.any], tryHarder: Bool = false, maxNumberOfSymbols: Int = 255) {
        var opts = ScannerOptions()
        opts.formats = formats
        opts.tryHarder = tryHarder
        opts.maxNumberOfSymbols = maxNumberOfSymbols
        self.options = opts
    }

    private func createZXIReader() -> ZXIBarcodeReader {
        let zxiOptions = ZXIReaderOptions()
        zxiOptions.formats = self.options.formats.map { NSNumber(value: $0.zxiFormat.rawValue) }
        zxiOptions.tryHarder = self.options.tryHarder
        zxiOptions.tryRotate = self.options.tryRotate
        zxiOptions.tryInvert = self.options.tryInvert
        zxiOptions.tryDownscale = self.options.tryDownscale
        zxiOptions.isPure = self.options.isPure
        zxiOptions.binarizer = ZXIBinarizer(rawValue: self.options.binarizer.rawValue) ?? .localAverage
        zxiOptions.downscaleFactor = self.options.downscaleFactor
        zxiOptions.downscaleThreshold = self.options.downscaleThreshold
        zxiOptions.minLineCount = self.options.minLineCount
        zxiOptions.maxNumberOfSymbols = self.options.maxNumberOfSymbols
        zxiOptions.returnErrors = self.options.returnErrors
        zxiOptions.eanAddOnSymbol = ZXIEanAddOnSymbol(rawValue: self.options.eanAddOnSymbol.rawValue) ?? .ignore
        zxiOptions.textMode = ZXITextMode(rawValue: self.options.textMode.rawValue) ?? .HRI
        return ZXIBarcodeReader(options: zxiOptions)
    }

    public func read(cgImage: CGImage) throws -> [BarcodeResult] {
        let reader = createZXIReader()
        let results = try reader.read(cgImage)
        return results.map { BarcodeResult(from: $0) }
    }

    public func read(ciImage: CIImage) throws -> [BarcodeResult] {
        let reader = createZXIReader()
        let results = try reader.read(ciImage)
        return results.map { BarcodeResult(from: $0) }
    }

    public func read(pixelBuffer: CVPixelBuffer) throws -> [BarcodeResult] {
        let reader = createZXIReader()
        let results = try reader.read(pixelBuffer)
        return results.map { BarcodeResult(from: $0) }
    }

    // Async/Await support for concurrent processing
    public func readAsync(cgImage: CGImage) async throws -> [BarcodeResult] {
        try await Task.detached(priority: .userInitiated) {
            try self.read(cgImage: cgImage)
        }.value
    }

    public func readAsync(ciImage: CIImage) async throws -> [BarcodeResult] {
        try await Task.detached(priority: .userInitiated) {
            try self.read(ciImage: ciImage)
        }.value
    }

    public func readAsync(pixelBuffer: CVPixelBuffer) async throws -> [BarcodeResult] {
        try await Task.detached(priority: .userInitiated) {
            try self.read(pixelBuffer: pixelBuffer)
        }.value
    }
}
