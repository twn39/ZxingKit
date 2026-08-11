import Foundation
import CoreGraphics
import CoreImage
import CoreVideo
import ZXingCpp

public enum ZxingError: Error, LocalizedError {
    case unreadableImage
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unreadableImage: return "Failed to process the image for reading."
        case .generationFailed(let message): return "Barcode generation failed: \(message)"
        }
    }
}

public enum BarcodeFormat: Int, CaseIterable, Hashable, Sendable {
    case none = 0
    case aztec
    case codabar
    case code39
    case code93
    case code128
    case dataBar
    case dataBarExpanded
    case dataBarStacked
    case dataBarExpandedStacked
    case dataBarLimited
    case dataMatrix
    case dxFilmEdge
    case telepen
    case ean8
    case ean13
    case itf
    case maxicode
    case pdf417
    case microPdf417
    case qrCode
    case microQrCode
    case rmqrCode
    case upcA
    case upcE
    case linearCodes
    case matrixCodes
    case any

    init(zxiFormat: ZXIFormat) {
        self = BarcodeFormat(rawValue: zxiFormat.rawValue) ?? .none
    }

    var zxiFormat: ZXIFormat {
        return ZXIFormat(rawValue: self.rawValue) ?? .NONE
    }
}

public enum Binarizer: Int, Sendable {
    case localAverage
    case globalHistogram
    case fixedThreshold
    case boolCast
}

public enum EanAddOnSymbol: Int, Sendable {
    case ignore
    case read
    case require
}

public enum TextMode: Int, Sendable {
    case plain
    case eci
    case hri
    case escaped
    case hex
    case hexEci
}

public struct Position {
    public let topLeft: CGPoint
    public let topRight: CGPoint
    public let bottomRight: CGPoint
    public let bottomLeft: CGPoint

    public var boundingBox: CGRect {
        let minX = min(topLeft.x, topRight.x, bottomRight.x, bottomLeft.x)
        let maxX = max(topLeft.x, topRight.x, bottomRight.x, bottomLeft.x)
        let minY = min(topLeft.y, topRight.y, bottomRight.y, bottomLeft.y)
        let maxY = max(topLeft.y, topRight.y, bottomRight.y, bottomLeft.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public var cgPath: CGPath {
        let path = CGMutablePath()
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.closeSubpath()
        return path
    }
}

public struct GTIN {
    public let country: String
    public let addOn: String
    public let price: String
    public let issueNumber: String
}

public struct BarcodeResult {
    public let text: String
    public let bytes: Data
    public let format: BarcodeFormat
    public let position: Position?
    public let orientation: Int
    public let ecLevel: String
    public let symbologyIdentifier: String
    public let sequenceSize: Int
    public let sequenceIndex: Int
    public let sequenceId: String
    public let readerInit: Bool
    public let lineCount: Int
    public let gtin: GTIN?

    init(from zxiResult: ZXIResult) {
        self.text = zxiResult.text
        self.bytes = zxiResult.bytes
        self.format = BarcodeFormat(zxiFormat: zxiResult.format)

        let pos = zxiResult.position
        self.position = Position(
            topLeft: CGPoint(x: CGFloat(pos.topLeft.x), y: CGFloat(pos.topLeft.y)),
            topRight: CGPoint(x: CGFloat(pos.topRight.x), y: CGFloat(pos.topRight.y)),
            bottomRight: CGPoint(x: CGFloat(pos.bottomRight.x), y: CGFloat(pos.bottomRight.y)),
            bottomLeft: CGPoint(x: CGFloat(pos.bottomLeft.x), y: CGFloat(pos.bottomLeft.y))
        )

        self.orientation = zxiResult.orientation
        self.ecLevel = zxiResult.ecLevel
        self.symbologyIdentifier = zxiResult.symbologyIdentifier
        self.sequenceSize = zxiResult.sequenceSize
        self.sequenceIndex = zxiResult.sequenceIndex
        self.sequenceId = zxiResult.sequenceId
        self.readerInit = zxiResult.readerInit
        self.lineCount = zxiResult.lineCount

        let g = zxiResult.gtin
        self.gtin = GTIN(country: g.country, addOn: g.addOn, price: g.price, issueNumber: g.issueNumber)
    }
}

/// Configuration options for the BarcodeScanner.
public struct ScannerOptions: Sendable {
    /// The specific formats to search for. Providing a narrow set improves performance and reduces false positives. Defaults to `.any`.
    public var formats: Set<BarcodeFormat> = [.any]

    /// Spend more time trying to find a barcode; optimizes for accuracy over speed. Defaults to `true`.
    public var tryHarder: Bool = true

    /// Also try detecting code in 90, 180 and 270 degree rotated images. Defaults to `true`.
    public var tryRotate: Bool = true

    /// Also try detecting code in inverted images. Defaults to `false`.
    public var tryInvert: Bool = false

    /// Also try detecting code in downscaled images (depends on `downscaleFactor`). Defaults to `true`.
    public var tryDownscale: Bool = true

    /// Set to true if the input contains nothing but a single perfectly aligned barcode (generated images). Defaults to `false`.
    public var isPure: Bool = false

    /// Algorithm to use for converting the grayscale image to a binary image. Defaults to `.localAverage`.
    public var binarizer: Binarizer = .localAverage

    /// Downscale factor to use for image downscaling. Defaults to 3.
    public var downscaleFactor: Int = 3

    /// Minimum width/height of the image to trigger downscaling. Defaults to 500.
    public var downscaleThreshold: Int = 500

    /// Minimum number of lines required to detect a 1D barcode. Defaults to 2.
    public var minLineCount: Int = 2

    /// Maximum number of barcodes to detect in a single scan. Defaults to 255.
    public var maxNumberOfSymbols: Int = 255

    /// If true, returns decoded barcodes even if checksums fail. Defaults to `false`.
    public var returnErrors: Bool = false

    /// Strategy to deal with EAN/UPC add-on symbols. Defaults to `.ignore`.
    public var eanAddOnSymbol: EanAddOnSymbol = .ignore

    /// Character set / encoding to use. Defaults to `.hri`.
    public var textMode: TextMode = .hri

    public init() {}
}

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

    public func readAsync(pixelBuffer: CVPixelBuffer) async throws -> [BarcodeResult] {
        try await Task.detached(priority: .userInitiated) {
            try self.read(pixelBuffer: pixelBuffer)
        }.value
    }
}

public class BarcodeGenerator {
    private let writer: ZXIBarcodeWriter

    public init(format: BarcodeFormat, width: Int = 0, height: Int = 0, margin: Int = -1, ecLevel: Int = -1) {
        let options = ZXIWriterOptions(format: format.zxiFormat)
        if width > 0 { options.width = Int32(width) }
        if height > 0 { options.height = Int32(height) }
        if margin >= 0 { options.margin = Int32(margin) }
        if ecLevel >= 0 { options.ecLevel = Int32(ecLevel) }
        self.writer = ZXIBarcodeWriter(options: options)
    }

    public func write(string: String) throws -> CGImage? {
        do {
            // CF_RETURNS_RETAINED means we don't need takeRetainedValue anymore
            return try writer.write(string)
        } catch {
            throw ZxingError.generationFailed(error.localizedDescription)
        }
    }

    public func write(data: Data) throws -> CGImage? {
        do {
            return try writer.write(data)
        } catch {
            throw ZxingError.generationFailed(error.localizedDescription)
        }
    }
}
