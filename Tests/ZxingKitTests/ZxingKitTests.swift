import Testing
import CoreGraphics
import ZXingCpp
@testable import ZxingKit

@Suite("ZxingKit Integration Tests")
struct ZxingKitTests {

    @Test("Generate and scan a QR Code")
    func testGenerateAndScanQRCode() throws {
        // 1. Generate QR Code
        let textToEncode = "Hello, ZxingKit!"
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)

        let cgImage = try generator.write(string: textToEncode)
        let unwrappedImage = try #require(cgImage, "Failed to generate CGImage")

        #expect(unwrappedImage.width <= 200 && unwrappedImage.width > 100)
        #expect(unwrappedImage.height <= 200 && unwrappedImage.height > 100)

        // 2. Scan QR Code
        let scanner = BarcodeScanner(formats: [.qrCode])
        let results = try scanner.read(cgImage: unwrappedImage)

        // 3. Verify Result
        #expect(results.count == 1)

        let firstResult = try #require(results.first)
        #expect(firstResult.text == textToEncode)
        #expect(firstResult.format == .qrCode)
    }

    @Test("Generate and scan an EAN-13 Barcode")
    func testGenerateAndScanEAN13() throws {
        // EAN-13 must be 12 or 13 digits (the last is a checksum).
        let ean13Code = "1234567890128"
        let generator = BarcodeGenerator(format: .ean13, width: 300, height: 100)

        let cgImage = try generator.write(string: ean13Code)
        let unwrappedImage = try #require(cgImage, "Failed to generate CGImage")

        let scanner = BarcodeScanner(formats: [.ean13])
        let results = try scanner.read(cgImage: unwrappedImage)

        #expect(results.count == 1)
        let firstResult = try #require(results.first)
        #expect(firstResult.text == ean13Code)
        #expect(firstResult.format == .ean13)
        
        // Verify GTIN properties parsed from EAN-13
        #expect(firstResult.gtin != nil)
    }

    @Test("Test missing barcode scanning")
    func testScanEmptyImage() throws {
        // Create an empty, white CGImage (no barcode)
        let context = CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 400, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        let emptyImage = try #require(context.makeImage())

        let scanner = BarcodeScanner()
        let results = try scanner.read(cgImage: emptyImage)

        #expect(results.isEmpty)
    }

    @Test("Generate and scan a MaxiCode using Zint")
    func testGenerateAndScanMaxiCode() throws {
        // MaxiCode is only generated if Zint is properly integrated
        let textToEncode = "Hello MaxiCode World"
        let generator = BarcodeGenerator(format: .maxicode)

        let cgImage = try generator.write(string: textToEncode)
        let unwrappedImage = try #require(cgImage, "Failed to generate CGImage for MaxiCode (Zint might not be active)")

        let scanner = BarcodeScanner(formats: [.maxicode])
        let results = try scanner.read(cgImage: unwrappedImage)

        #expect(results.count == 1)
        let firstResult = try #require(results.first)
        #expect(firstResult.format == .maxicode)
    }
    
    // MARK: - New Advanced Tests
    
    @Test("Async scanning processing")
    func testAsyncScanning() async throws {
        let textToEncode = "Async/Await testing"
        let generator = BarcodeGenerator(format: .dataMatrix, width: 150, height: 150)
        
        let cgImage = try #require(try generator.write(string: textToEncode))
        let scanner = BarcodeScanner(formats: [.dataMatrix])
        
        // Run asynchronously
        let results = try await scanner.readAsync(cgImage: cgImage)
        
        #expect(results.count == 1)
        #expect(results.first?.text == textToEncode)
        #expect(results.first?.format == .dataMatrix)
    }
    
    @Test("Scanner formats filtering")
    func testScannerFormatFiltering() throws {
        let textToEncode = "Test Data"
        let generator = BarcodeGenerator(format: .code128, width: 200, height: 50)
        let cgImage = try #require(try generator.write(string: textToEncode))
        
        // Scan expecting a completely different format -> Should fail to find it
        let wrongScanner = BarcodeScanner(formats: [.qrCode, .ean13])
        let emptyResults = try wrongScanner.read(cgImage: cgImage)
        #expect(emptyResults.isEmpty, "Scanner should not find a Code128 if not instructed to search for it")
        
        // Scan with correct format
        let correctScanner = BarcodeScanner(formats: [.code128])
        let results = try correctScanner.read(cgImage: cgImage)
        #expect(results.count == 1)
        #expect(results.first?.text == textToEncode)
    }
    
    @Test("Test position and bounding box parsing")
    func testPositionParsing() throws {
        let textToEncode = "PosTest"
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)
        let cgImage = try #require(try generator.write(string: textToEncode))
        
        let scanner = BarcodeScanner(formats: [.qrCode])
        let result = try #require(try scanner.read(cgImage: cgImage).first)
        
        // 1. Ensure position is populated
        let position = try #require(result.position)
        
        // 2. Validate geometric bounding box is reasonable (within 0...200)
        let box = position.boundingBox
        #expect(box.width > 50 && box.width <= 200)
        #expect(box.height > 50 && box.height <= 200)
        #expect(box.minX >= 0 && box.maxX <= 200)
        #expect(box.minY >= 0 && box.maxY <= 200)
        
        // 3. Validate path generation
        #expect(!position.cgPath.isEmpty)
    }
    
    @Test("Generation error handling (ZxingError verification)")
    func testGenerationErrorHandling() throws {
        // EAN-13 expects strictly numeric values. Letters should throw an error.
        let generator = BarcodeGenerator(format: .ean13)
        
        #expect(throws: ZxingError.self) {
            _ = try generator.write(string: "INVALID_LETTERS")
        }
        
        let err = ZxingError.generationFailed("Test Failure")
        #expect(err.errorDescription?.contains("Test Failure") == true)
        #expect(ZxingError.unreadableImage.errorDescription != nil)
    }

    // MARK: - Upstream Sync & Defensive Tests

    @Test("1-to-1 BarcodeFormat raw value mapping verification")
    func testBarcodeFormat1To1Mapping() throws {
        // 1. Ensure count matches expected 28 formats (0...27)
        #expect(BarcodeFormat.allCases.count == 28)

        // 2. Iterate through all cases and verify bidirectional mapping and exact raw values
        for format in BarcodeFormat.allCases {
            let zxiFormat = format.zxiFormat
            #expect(zxiFormat.rawValue == format.rawValue, "Format \(format) rawValue \(format.rawValue) mismatch with ZXIFormat \(zxiFormat.rawValue)")
            
            let reverseFormat = BarcodeFormat(zxiFormat: zxiFormat)
            #expect(reverseFormat == format, "Bidirectional conversion failed for format \(format)")
        }
    }

    @Test("Defensive handling for invalid enum raw values")
    func testDefensiveEnumMapping() throws {
        // Test fallback to .none for unknown raw values
        let invalidZXIFormat = ZXIFormat(rawValue: 9999) ?? .NONE
        let fallbackFormat = BarcodeFormat(zxiFormat: invalidZXIFormat)
        #expect(fallbackFormat == .none, "Unknown ZXIFormat rawValue should fall back to .none")
    }

    @Test("Async generation and CIImage scanning")
    func testAsyncGeneratorAndCIImageScanner() async throws {
        let textToEncode = "CIImage Async test"
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)

        // Async write
        let cgImage = try #require(try await generator.writeAsync(string: textToEncode))
        let ciImage = CIImage(cgImage: cgImage)

        // Async read from CIImage
        let scanner = BarcodeScanner(formats: [.qrCode])
        let results = try await scanner.readAsync(ciImage: ciImage)

        #expect(results.count == 1)
        #expect(results.first?.text == textToEncode)
    }
}
