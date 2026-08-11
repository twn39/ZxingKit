import Foundation
import ZXingCpp

/// Specifies the supported 1D linear and 2D matrix barcode symbologies.
public enum BarcodeFormat: Int, CaseIterable, Hashable, Sendable {
    /// No barcode format specified or unrecognized format.
    case none = 0
    /// Aztec 2D matrix code.
    case aztec
    /// Codabar 1D linear code.
    case codabar
    /// Code 39 1D linear code.
    case code39
    /// Code 93 1D linear code.
    case code93
    /// Code 128 1D linear code.
    case code128
    /// GS1 DataBar (RSS-14) 1D linear code.
    case dataBar
    /// GS1 DataBar Expanded 1D linear code.
    case dataBarExpanded
    /// GS1 DataBar Stacked 1D linear code.
    case dataBarStacked
    /// GS1 DataBar Expanded Stacked 1D linear code.
    case dataBarExpandedStacked
    /// GS1 DataBar Limited 1D linear code.
    case dataBarLimited
    /// Data Matrix 2D matrix code.
    case dataMatrix
    /// DX Film Edge 1D code.
    case dxFilmEdge
    /// Telepen 1D linear code.
    case telepen
    /// EAN-8 1D linear code.
    case ean8
    /// EAN-13 1D linear code.
    case ean13
    /// Interleaved 2 of 5 (ITF) 1D linear code.
    case itf
    /// MaxiCode 2D matrix code.
    case maxicode
    /// PDF417 2D stacked linear code.
    case pdf417
    /// MicroPDF417 2D stacked linear code.
    case microPdf417
    /// QR Code 2D matrix code.
    case qrCode
    /// Micro QR Code 2D matrix code.
    case microQrCode
    /// Rectangular Micro QR Code (rMQR).
    case rmqrCode
    /// UPC-A 1D linear code.
    case upcA
    /// UPC-E 1D linear code.
    case upcE
    /// Combination filter for all 1D linear barcode formats.
    case linearCodes
    /// Combination filter for all 2D matrix barcode formats.
    case matrixCodes
    /// Wildcard format filter matching any supported barcode symbology.
    case any

    init(zxiFormat: ZXIFormat) {
        self = BarcodeFormat(rawValue: zxiFormat.rawValue) ?? .none
    }

    var zxiFormat: ZXIFormat {
        return ZXIFormat(rawValue: self.rawValue) ?? .NONE
    }
}

/// Image binarization algorithms used during barcode scanning preprocessing.
public enum Binarizer: Int, Sendable {
    /// Local adaptive thresholding based on local pixel averages.
    case localAverage
    /// Global histogram-based thresholding (Otsu's binarization).
    case globalHistogram
    /// Fixed threshold value binarization.
    case fixedThreshold
    /// Direct boolean cast binarization.
    case boolCast
}

/// Configures handling options for EAN-2 and EAN-5 add-on barcode extensions.
public enum EanAddOnSymbol: Int, Sendable {
    /// Ignore EAN add-on symbols if present.
    case ignore
    /// Read EAN add-on symbols if present, but do not require them.
    case read
    /// Require EAN add-on symbols to be present for EAN barcodes.
    case require
}

/// Specifies text interpretation mode for decoded barcode payload bytes.
public enum TextMode: Int, Sendable {
    /// Raw unescaped plain text decoding.
    case plain
    /// ECI (Extended Channel Interpretation) escape sequence processing.
    case eci
    /// Human Readable Interpretation (HRI) mode.
    case hri
    /// Escaped byte representation.
    case escaped
    /// Hexadecimal string representation of raw bytes.
    case hex
    /// Hexadecimal representation with ECI markers.
    case hexEci
}
