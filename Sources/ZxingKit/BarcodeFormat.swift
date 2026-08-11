import Foundation
import ZXingCpp

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
