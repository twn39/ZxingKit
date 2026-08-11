import Foundation

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
