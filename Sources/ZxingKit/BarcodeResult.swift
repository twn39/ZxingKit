import Foundation
import CoreGraphics
import ZXingCpp

/// Represents the quadrilateral corner positions of a detected barcode in image pixel space.
public struct Position: Sendable, Equatable, Codable {
    /// Top-left corner point.
    public let topLeft: CGPoint
    /// Top-right corner point.
    public let topRight: CGPoint
    /// Bottom-right corner point.
    public let bottomRight: CGPoint
    /// Bottom-left corner point.
    public let bottomLeft: CGPoint

    /// Calculates the axis-aligned bounding box encompassing all 4 corner points.
    public var boundingBox: CGRect {
        let minX = min(topLeft.x, topRight.x, bottomRight.x, bottomLeft.x)
        let maxX = max(topLeft.x, topRight.x, bottomRight.x, bottomLeft.x)
        let minY = min(topLeft.y, topRight.y, bottomRight.y, bottomLeft.y)
        let maxY = max(topLeft.y, topRight.y, bottomRight.y, bottomLeft.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Constructs a `CGPath` connecting the 4 quadrilateral corner points.
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

/// Contains parsed GS1 Global Trade Item Number (GTIN) metadata for UPC/EAN barcodes.
public struct GTIN: Sendable, Equatable, Codable {
    /// Country or issuing organization name.
    public let country: String
    /// EAN-2 or EAN-5 add-on payload.
    public let addOn: String
    /// Encoded product price if present.
    public let price: String
    /// Issue number if present.
    public let issueNumber: String
}

/// Contains all decoded metadata for a detected barcode.
public struct BarcodeResult: Sendable, Equatable, Codable {
    /// The decoded text content of the barcode.
    public let text: String
    /// The raw byte payload of the barcode.
    public let bytes: Data
    /// The detected ``BarcodeFormat``.
    public let format: BarcodeFormat
    /// Quadrilateral corner position points in pixel space, if available.
    public let position: Position?
    /// Rotation orientation angle in degrees (0, 90, 180, 270).
    public let orientation: Int
    /// Error correction level string (e.g. "L", "M", "Q", "H").
    public let ecLevel: String
    /// GS1 Symbology Identifier prefix (e.g. "]Q1").
    public let symbologyIdentifier: String
    /// Sequence size for Structured Append barcodes (-1 if not part of a sequence).
    public let sequenceSize: Int
    /// Sequence index for Structured Append barcodes (-1 if not part of a sequence).
    public let sequenceIndex: Int
    /// Sequence ID string for Structured Append barcodes.
    public let sequenceId: String
    /// Indicates whether the barcode contains a reader initialization command.
    public let readerInit: Bool
    /// Number of barcode scan lines intersected during decoding.
    public let lineCount: Int
    /// Parsed ``GTIN`` metadata if the format is EAN or UPC.
    public let gtin: GTIN?

    init(from zxiResult: ZXIResult) {
        self.text = zxiResult.text
        self.bytes = zxiResult.bytes
        self.format = BarcodeFormat(zxiFormat: zxiResult.format)

        // Issue #2: Use the C++ position.isValid() flag exposed via hasValidPosition.
        // This is semantically accurate — e.g., valid 1D scan-line endpoints are non-zero
        // even if the barcode sits at the image origin.
        let pos = zxiResult.position
        self.position = zxiResult.hasValidPosition ? Position(
            topLeft: CGPoint(x: CGFloat(pos.topLeft.x), y: CGFloat(pos.topLeft.y)),
            topRight: CGPoint(x: CGFloat(pos.topRight.x), y: CGFloat(pos.topRight.y)),
            bottomRight: CGPoint(x: CGFloat(pos.bottomRight.x), y: CGFloat(pos.bottomRight.y)),
            bottomLeft: CGPoint(x: CGFloat(pos.bottomLeft.x), y: CGFloat(pos.bottomLeft.y))
        ) : nil

        self.orientation = zxiResult.orientation
        self.ecLevel = zxiResult.ecLevel
        self.symbologyIdentifier = zxiResult.symbologyIdentifier
        self.sequenceSize = zxiResult.sequenceSize
        self.sequenceIndex = zxiResult.sequenceIndex
        self.sequenceId = zxiResult.sequenceId
        self.readerInit = zxiResult.readerInit
        self.lineCount = zxiResult.lineCount

        // Issue #3: gtin is now nullable in the ObjC bridge; nil for non-EAN/UPC formats.
        if let g = zxiResult.gtin {
            self.gtin = GTIN(country: g.country, addOn: g.addOn, price: g.price, issueNumber: g.issueNumber)
        } else {
            self.gtin = nil
        }
    }
}
