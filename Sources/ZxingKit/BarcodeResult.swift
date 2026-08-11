import Foundation
import CoreGraphics
import ZXingCpp

public struct Position: Sendable {
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

public struct GTIN: Sendable {
    public let country: String
    public let addOn: String
    public let price: String
    public let issueNumber: String
}

public struct BarcodeResult: Sendable {
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
