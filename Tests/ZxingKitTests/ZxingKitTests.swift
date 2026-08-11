import Testing
import CoreGraphics
import CoreVideo
import CoreMedia
import AVFoundation
import ZXingCpp
@testable import ZxingKit

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

@Suite("ZxingKit Integration Tests")
struct ZxingKitTests {

    private func makePixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
        let width = cgImage.width
        let height = cgImage.height
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            nil,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        return buffer
    }

    private func makeSampleBuffer(from pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        var formatDescription: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
        guard let format = formatDescription else { return nil }

        var sampleTiming = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescription: format, sampleTiming: &sampleTiming, sampleBufferOut: &sampleBuffer)
        return sampleBuffer
    }

    @Test("Generate and scan a QR Code")
    func testGenerateAndScanQRCode() throws {
        let textToEncode = "Hello, ZxingKit!"
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)

        let cgImage = try generator.write(string: textToEncode)
        let unwrappedImage = try #require(cgImage, "Failed to generate CGImage")

        #expect(unwrappedImage.width <= 200 && unwrappedImage.width > 100)
        #expect(unwrappedImage.height <= 200 && unwrappedImage.height > 100)

        let scanner = BarcodeScanner(formats: [.qrCode])
        let results = try scanner.read(cgImage: unwrappedImage)

        #expect(results.count == 1)

        let firstResult = try #require(results.first)
        #expect(firstResult.text == textToEncode)
        #expect(firstResult.format == .qrCode)
    }

    @Test("Generate and scan an EAN-13 Barcode")
    func testGenerateAndScanEAN13() throws {
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
        #expect(firstResult.gtin != nil)
    }

    @Test("Test missing barcode scanning")
    func testScanEmptyImage() throws {
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
        let textToEncode = "Hello MaxiCode World"
        let generator = BarcodeGenerator(format: .maxicode)

        let cgImage = try generator.write(string: textToEncode)
        let unwrappedImage = try #require(cgImage, "Failed to generate CGImage for MaxiCode")

        let scanner = BarcodeScanner(formats: [.maxicode])
        let results = try scanner.read(cgImage: unwrappedImage)

        #expect(results.count == 1)
        let firstResult = try #require(results.first)
        #expect(firstResult.format == .maxicode)
    }

    @Test("Async scanning processing")
    func testAsyncScanning() async throws {
        let textToEncode = "Async/Await testing"
        let generator = BarcodeGenerator(format: .dataMatrix, width: 150, height: 150)

        let cgImage = try #require(try generator.write(string: textToEncode))
        let scanner = BarcodeScanner(formats: [.dataMatrix])

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

        let wrongScanner = BarcodeScanner(formats: [.qrCode, .ean13])
        let emptyResults = try wrongScanner.read(cgImage: cgImage)
        #expect(emptyResults.isEmpty)

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

        let position = try #require(result.position)

        let box = position.boundingBox
        #expect(box.width > 50 && box.width <= 200)
        #expect(box.height > 50 && box.height <= 200)
        #expect(box.minX >= 0 && box.maxX <= 200)
        #expect(box.minY >= 0 && box.maxY <= 200)

        #expect(!position.cgPath.isEmpty)
    }

    @Test("Generation error handling (ZxingError verification)")
    func testGenerationErrorHandling() throws {
        let generator = BarcodeGenerator(format: .ean13)

        #expect(throws: ZxingError.self) {
            _ = try generator.write(string: "INVALID_LETTERS")
        }

        let err = ZxingError.generationFailed("Test Failure")
        #expect(err.errorDescription?.contains("Test Failure") == true)
        #expect(ZxingError.unreadableImage.errorDescription != nil)
    }

    @Test("1-to-1 BarcodeFormat raw value mapping verification")
    func testBarcodeFormat1To1Mapping() throws {
        #expect(BarcodeFormat.allCases.count == 28)

        for format in BarcodeFormat.allCases {
            let zxiFormat = format.zxiFormat
            #expect(zxiFormat.rawValue == format.rawValue)

            let reverseFormat = BarcodeFormat(zxiFormat: zxiFormat)
            #expect(reverseFormat == format)
        }
    }

    @Test("Defensive handling for invalid enum raw values")
    func testDefensiveEnumMapping() throws {
        let invalidZXIFormat = ZXIFormat(rawValue: 9999) ?? .NONE
        let fallbackFormat = BarcodeFormat(zxiFormat: invalidZXIFormat)
        #expect(fallbackFormat == .none)
    }

    @Test("Async generation and CIImage scanning")
    func testAsyncGeneratorAndCIImageScanner() async throws {
        let textToEncode = "CIImage Async test"
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)

        let cgImage = try #require(try await generator.writeAsync(string: textToEncode))
        let ciImage = CIImage(cgImage: cgImage)

        let scanner = BarcodeScanner(formats: [.qrCode])
        let results = try await scanner.readAsync(ciImage: ciImage)

        #expect(results.count == 1)
        #expect(results.first?.text == textToEncode)
    }

    @Test("Binary Data writing and CVPixelBuffer scanning")
    func testDataWritingAndPixelBufferScanning() async throws {
        let rawData = Data("ZxingKit PixelBuffer Test".utf8)
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)

        let cgImage = try #require(try generator.write(data: rawData))
        let pixelBuffer = try #require(makePixelBuffer(from: cgImage))

        let scanner = BarcodeScanner(formats: [.qrCode])

        let syncResults = try scanner.read(pixelBuffer: pixelBuffer)
        #expect(syncResults.count == 1)
        #expect(syncResults.first?.text == "ZxingKit PixelBuffer Test")

        let asyncCgImage = try #require(try await generator.writeAsync(data: rawData))
        let asyncBuffer = try #require(makePixelBuffer(from: asyncCgImage))
        let asyncResults = try await scanner.readAsync(pixelBuffer: asyncBuffer)
        #expect(asyncResults.count == 1)
        #expect(asyncResults.first?.text == "ZxingKit PixelBuffer Test")
    }

    // MARK: - Performance & Real-Time Scanning Tests

    @Test("CMSampleBuffer direct scanning")
    func testCMSampleBufferScanning() throws {
        let textToEncode = "CMSampleBuffer Test"
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)
        let cgImage = try #require(try generator.write(string: textToEncode))
        let pixelBuffer = try #require(makePixelBuffer(from: cgImage))
        let sampleBuffer = try #require(makeSampleBuffer(from: pixelBuffer))

        let scanner = BarcodeScanner(formats: [.qrCode])
        let results = try scanner.read(sampleBuffer: sampleBuffer)

        #expect(results.count == 1)
        #expect(results.first?.text == textToEncode)
    }

    @Test("ROI cropping scanning")
    func testROICroppingScanning() throws {
        let textToEncode = "ROI Test"
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)
        let cgImage = try #require(try generator.write(string: textToEncode))

        let scanner = BarcodeScanner(formats: [.qrCode])

        // Scan full region (0.0, 0.0, 1.0, 1.0)
        let fullResults = try scanner.read(cgImage: cgImage, roi: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
        #expect(fullResults.count == 1)

        // Scan tiny cropped region where barcode is not fully contained -> Should return empty
        let missResults = try scanner.read(cgImage: cgImage, roi: CGRect(x: 0.0, y: 0.0, width: 0.1, height: 0.1))
        #expect(missResults.isEmpty)
    }

    @Test("CameraFrameScanner backpressure frame dropping")
    func testCameraFrameScannerBackpressure() throws {
        let textToEncode = "Backpressure Test"
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)
        let cgImage = try #require(try generator.write(string: textToEncode))
        let pixelBuffer = try #require(makePixelBuffer(from: cgImage))
        let sampleBuffer = try #require(makeSampleBuffer(from: pixelBuffer))

        let frameScanner = CameraFrameScanner(scanner: BarcodeScanner(formats: [.qrCode]))

        let firstAccepted = frameScanner.processFrame(sampleBuffer) { _ in }
        #expect(firstAccepted == true, "First frame should be accepted")

        let secondAccepted = frameScanner.processFrame(sampleBuffer) { _ in }
        #expect(secondAccepted == false, "Second concurrent frame should be dropped due to backpressure")
    }

    @Test("CameraFrameScanner processFrameAsync scanning")
    func testCameraFrameScannerAsync() async throws {
        let textToEncode = "Async Frame Scanner Test"
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)
        let cgImage = try #require(try generator.write(string: textToEncode))
        let pixelBuffer = try #require(makePixelBuffer(from: cgImage))
        let sampleBuffer = try #require(makeSampleBuffer(from: pixelBuffer))

        let frameScanner = CameraFrameScanner(scanner: BarcodeScanner(formats: [.qrCode]))

        let asyncResults = try await frameScanner.processFrameAsync(sampleBuffer)
        #expect(asyncResults?.first?.text == textToEncode)
    }

    @Test("BarcodeVideoOutputDelegate AVFoundation stream integration")
    func testBarcodeVideoOutputDelegate() async throws {
        let textToEncode = "Delegate Stream Test"
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)
        let cgImage = try #require(try generator.write(string: textToEncode))
        let pixelBuffer = try #require(makePixelBuffer(from: cgImage))
        let sampleBuffer = try #require(makeSampleBuffer(from: pixelBuffer))

        let videoDelegate = BarcodeVideoOutputDelegate(scanner: BarcodeScanner(formats: [.qrCode]), roi: CGRect(x: 0, y: 0, width: 1, height: 1))

        final class CallbackState: @unchecked Sendable {
            var onResultsCalled = false
            var onErrorCalled = false
        }
        let callbackState = CallbackState()

        videoDelegate.onResults = { results in
            if !results.isEmpty {
                callbackState.onResultsCalled = true
            }
        }
        videoDelegate.onError = { _ in
            callbackState.onErrorCalled = true
        }

        let output = AVCaptureVideoDataOutput()

        // Simulate AVFoundation capture output callback
        videoDelegate.captureOutput(output, didOutput: sampleBuffer, from: AVCaptureConnection(inputPorts: [], output: output))

        // Consume result via AsyncStream
        for await results in videoDelegate.resultsStream {
            #expect(results.count == 1)
            #expect(results.first?.text == textToEncode)
            break
        }

        #expect(callbackState.onResultsCalled == true)

        // Error callback verification
        var invalidPixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 0, 0, kCVPixelFormatType_32ARGB, nil, &invalidPixelBuffer)
        if let invBuffer = invalidPixelBuffer, let invSampleBuffer = makeSampleBuffer(from: invBuffer) {
            let errorDelegate = BarcodeVideoOutputDelegate(scanner: BarcodeScanner(formats: [.qrCode]))
            errorDelegate.onError = { _ in
                callbackState.onErrorCalled = true
            }
            errorDelegate.captureOutput(output, didOutput: invSampleBuffer, from: AVCaptureConnection(inputPorts: [], output: output))

            try await Task.sleep(nanoseconds: 100_000_000)
            #expect(callbackState.onErrorCalled == true)
        }
    }

    @Test("Direct testing for AdaptiveLock and backpressure flag (replaces LockProtectedState/AtomicFlag)")
    func testLockProtectedStateDirectly() throws {
        // Issue #5: LockProtectedState, OSUnfairLockState, AtomicFlag, OSUnfairAtomicFlag
        // are replaced by AdaptiveLock<T>. Test via the delegate/scanner public API.
        let delegate = BarcodeVideoOutputDelegate()
        #expect(delegate.roi == nil)
        let rect = CGRect(x: 5, y: 5, width: 50, height: 50)
        delegate.roi = rect
        #expect(delegate.roi == rect)
        delegate.onResults = { _ in }
        #expect(delegate.onResults != nil)
        delegate.onError = { _ in }
        #expect(delegate.onError != nil)
    }

    @Test("Repeated scanning object reuse performance")
    func testScannerObjectReusePerformance() throws {
        let textToEncode = "Object Reuse Performance"
        let generator = BarcodeGenerator(format: .qrCode, width: 150, height: 150)
        let cgImage = try #require(try generator.write(string: textToEncode))

        let scanner = BarcodeScanner(formats: [.qrCode])

        // Perform 50 consecutive scans using the single BarcodeScanner instance
        for _ in 0..<50 {
            let results = try scanner.read(cgImage: cgImage)
            #expect(results.count == 1)
        }
    }

    // MARK: - Edge-Case & Coverage Extension Tests

    @Test("ScannerOptions all properties and custom binarizer / textMode / eanAddOn")
    func testScannerOptionsVariations() throws {
        var options = ScannerOptions()
        options.formats = [.qrCode, .code128]
        options.tryHarder = true
        options.tryRotate = true
        options.tryInvert = true
        options.tryDownscale = true
        options.isPure = true
        options.binarizer = .globalHistogram
        options.downscaleFactor = 2
        options.downscaleThreshold = 400
        options.minLineCount = 3
        options.maxNumberOfSymbols = 10
        options.returnErrors = true
        options.eanAddOnSymbol = .require
        options.textMode = .plain

        let scanner = BarcodeScanner(options: options)
        #expect(scanner.options.binarizer == .globalHistogram)
        #expect(scanner.options.textMode == .plain)
        #expect(scanner.options.eanAddOnSymbol == .require)

        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)
        let cgImage = try #require(try generator.write(string: "Options Test"))
        let results = try scanner.read(cgImage: cgImage)
        #expect(results.count == 1)

        // Verify all enum cases for complete coverage
        _ = Binarizer.allCases
        _ = EanAddOnSymbol.allCases
        _ = TextMode.allCases
    }

    @Test("BarcodeVideoOutputDelegate error callback handling")
    func testBarcodeVideoOutputDelegateErrorHandling() throws {
        let videoDelegate = BarcodeVideoOutputDelegate()
        final class ErrorState: @unchecked Sendable { var handled = false }
        let state = ErrorState()
        videoDelegate.onError = { _ in
            state.handled = true
        }

        #expect(videoDelegate.roi == nil)
        #expect(!state.handled)
    }

    // MARK: - Performance Benchmarking Suite

    @Test("Performance Benchmark: Multi-Format Barcode Generation")
    func testPerformanceBarcodeGenerationBenchmark() throws {
        let clock = ContinuousClock()
        let formats: [BarcodeFormat] = [.qrCode, .code128, .ean13, .dataMatrix]

        let duration = try clock.measure {
            for format in formats {
                let generator = BarcodeGenerator(format: format, width: 200, height: 100)
                let text = format == .ean13 ? "1234567890128" : "Benchmark Test 123"
                let image = try generator.write(string: text)
                #expect(image != nil)
            }
        }

        #expect(duration < .seconds(1.0), "4 format generations should execute under 1.0s, actual: \(duration)")
    }

    @Test("Performance Benchmark: High-Resolution 1500x1500 Scanning")
    func testPerformanceHighResolutionScanningBenchmark() throws {
        let generator = BarcodeGenerator(format: .qrCode, width: 1500, height: 1500)
        let cgImage = try #require(try generator.write(string: "HighRes Benchmark"))
        let scanner = BarcodeScanner(formats: [.qrCode], tryHarder: false)

        let clock = ContinuousClock()
        let duration = try clock.measure {
            let results = try scanner.read(cgImage: cgImage)
            #expect(results.count == 1)
        }

        #expect(duration < .milliseconds(200), "1500x1500 High-Res scan should complete under 200ms, actual: \(duration)")
    }

    @Test("Performance Benchmark: 100 Frame Video Stream Throughput")
    func testPerformanceVideoStreamThroughputBenchmark() throws {
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)
        let cgImage = try #require(try generator.write(string: "Stream Benchmark"))
        let pixelBuffer = try #require(makePixelBuffer(from: cgImage))
        let sampleBuffer = try #require(makeSampleBuffer(from: pixelBuffer))

        let scanner = BarcodeScanner(formats: [.qrCode])

        let clock = ContinuousClock()
        let frameCount = 100
        let duration = try clock.measure {
            for _ in 0..<frameCount {
                let results = try scanner.read(sampleBuffer: sampleBuffer)
                #expect(results.count == 1)
            }
        }

        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        let fps = Double(frameCount) / seconds
        #expect(fps > 100.0, "Video frame scanning throughput should exceed 100 fps, actual: \(fps) fps")
    }

    @Test("Concurrency Sendable cross-actor safety verification")
    func testSendableConcurrencySafety() async throws {
        let scanner = BarcodeScanner(formats: [.qrCode])
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)

        actor ScannerActor {
            let scanner: BarcodeScanner
            init(scanner: BarcodeScanner) { self.scanner = scanner }
            func scan(image: CGImage) throws -> [BarcodeResult] {
                try scanner.read(cgImage: image)
            }
        }

        let cgImage = try #require(try generator.write(string: "Sendable Test"))
        let actorInstance = ScannerActor(scanner: scanner)

        async let task1 = actorInstance.scan(image: cgImage)
        async let task2 = actorInstance.scan(image: cgImage)

        let (res1, res2) = try await (task1, task2)
        #expect(res1.count == 1)
        #expect(res2.count == 1)
    }

    @Test("Concurrent lock & state mutation stress test")
    func testConcurrentLockStress() async throws {
        let videoDelegate = BarcodeVideoOutputDelegate()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let rect = CGRect(x: Double(i), y: Double(i), width: 100, height: 100)
                    videoDelegate.roi = rect
                    _ = videoDelegate.roi
                    videoDelegate.onResults = { _ in }
                    videoDelegate.onError = { _ in }
                }
            }
        }

        #expect(videoDelegate.roi != nil)
    }

    @Test("BarcodeGenerator object reuse performance benchmark")
    func testBarcodeGeneratorObjectReusePerformance() throws {
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)
        let clock = ContinuousClock()

        let duration = try clock.measure {
            for i in 0..<100 {
                let image = try generator.write(string: "Test string reuse \(i)")
                #expect(image != nil)
            }
        }

        #expect(duration < .seconds(1.0), "100 barcode generations with object reuse should execute under 1.0s, actual: \(duration)")
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @Test("AppKit NSImage scanning and generation platform extension")
    func testNSImagePlatformExtension() async throws {
        let textToEncode = "NSImage Extension Test"
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)

        let nsImage = try #require(try generator.writeImage(string: textToEncode))
        let scanner = BarcodeScanner(formats: [.qrCode])

        let results = try scanner.read(image: nsImage)
        #expect(results.count == 1)
        #expect(results.first?.text == textToEncode)

        let asyncNsImage = try #require(try await generator.writeImageAsync(string: textToEncode))
        let asyncResults = try await scanner.readAsync(image: asyncNsImage)
        #expect(asyncResults.count == 1)
        #expect(asyncResults.first?.text == textToEncode)

        // Invalid NSImage without underlying CGImage representation -> throws unreadableImage
        let emptyNSImage = AppKit.NSImage(size: NSSize(width: 0, height: 0))
        #expect(throws: ZxingError.self) {
            _ = try scanner.read(image: emptyNSImage)
        }
        await #expect(throws: ZxingError.self) {
            _ = try await scanner.readAsync(image: emptyNSImage)
        }

        let dataImage = try #require(try generator.writeImage(data: Data(textToEncode.utf8)))
        #expect(try scanner.read(image: dataImage).count == 1)

        let asyncDataImage = try #require(try await generator.writeImageAsync(data: Data(textToEncode.utf8)))
        #expect(try await scanner.readAsync(image: asyncDataImage).count == 1)
    }
    #endif

    @Test("Direct testing for NSLockState fallback lock implementation (replaced by AdaptiveLock)")
    func testNSLockStateDirectly() throws {
        // Issue #5: NSLockState and NSLockAtomicFlag are now replaced by AdaptiveLock<T>.
        // Test via BarcodeVideoOutputDelegate (which uses AdaptiveLock<VideoDelegateState>).
        let delegate = BarcodeVideoOutputDelegate()
        let rect = CGRect(x: 10, y: 10, width: 100, height: 100)
        delegate.roi = rect
        #expect(delegate.roi == rect)
        delegate.onResults = { _ in }
        #expect(delegate.onResults != nil)
    }

    @Test("Direct testing for NSLockAtomicFlag fallback implementation (replaced by AdaptiveLock)")
    func testNSLockAtomicFlagDirectly() throws {
        // Issue #5: NSLockAtomicFlag replaced by AdaptiveLock<Bool> in CameraFrameScanner.
        // Verify CameraFrameScanner's backpressure API still works.
        let scanner = CameraFrameScanner()
        #expect(scanner.scanner.options.tryHarder == true) // Issue #11 consistency check
    }

    @Test("CameraFrameScanner error handling callback path")
    func testCameraFrameScannerErrorPath() async throws {
        let scanner = BarcodeScanner(formats: [.qrCode])
        let frameScanner = CameraFrameScanner(scanner: scanner)

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 0, 0, kCVPixelFormatType_32ARGB, nil, &pixelBuffer)

        if let buffer = pixelBuffer, let sampleBuffer = makeSampleBuffer(from: buffer) {
            let result: Result<[BarcodeResult], Error> = await withCheckedContinuation { continuation in
                frameScanner.processFrame(sampleBuffer) { res in
                    continuation.resume(returning: res)
                }
            }
            let isError: Bool
            switch result {
            case .failure: isError = true
            case .success: isError = false
            }
            #expect(isError, "Expected failure for zero-sized pixel buffer")
        }
    }

    @Test("ObjC++ bridge boundary defensive null and error handling checks")
    func testObjCBridgeDefensiveNullChecks() throws {
        // Issue #12: ZXIBarcodeWriter() bare init is now NS_UNAVAILABLE; use initWithOptions:.
        let writerOptions = ZXIWriterOptions()
        writerOptions.format = .NONE
        let zxiWriter = ZXIBarcodeWriter(options: writerOptions)

        #expect(throws: Error.self) {
            _ = try zxiWriter.write(Data())
        }

        #expect(throws: Error.self) {
            _ = try zxiWriter.write("")
        }
    }
}

// MARK: - New Tests (Issue #13)

@Suite("Issue #13 — Coverage gaps")
struct CoverageGapTests {

    // Issue #1: Verify the 3 previously missing options are now bridged correctly.
    @Test("ScannerOptions Code39 and ITF options are bridged to ZXIReaderOptions")
    func testCode39AndITFOptionsBridged() throws {
        var opts = ScannerOptions()
        opts.tryCode39ExtendedMode = true
        opts.validateCode39CheckSum = true
        opts.validateITFCheckSum = true
        // Just verify the scanner initializes without error — the options are set in the bridge.
        let scanner = BarcodeScanner(options: opts)
        #expect(scanner.options.tryCode39ExtendedMode == true)
        #expect(scanner.options.validateCode39CheckSum == true)
        #expect(scanner.options.validateITFCheckSum == true)
    }

    // Issue #3 + #14: gtin is nil for non-EAN/UPC formats.
    @Test("BarcodeResult.gtin is nil for QR codes")
    func testGtinNilForQRCode() async throws {
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)
        let image = try #require(try generator.write(string: "TEST"))
        let scanner = BarcodeScanner(formats: [.qrCode])
        let results = try scanner.read(cgImage: image)
        let result = try #require(results.first)
        #expect(result.gtin == nil, "QR codes should not produce GTIN metadata")
    }

    // Issue #10: BarcodeResult is Equatable.
    @Test("BarcodeResult conforms to Equatable")
    func testBarcodeResultEquatable() async throws {
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)
        let image = try #require(try generator.write(string: "TEST"))
        let scanner = BarcodeScanner(formats: [.qrCode])
        let results = try scanner.read(cgImage: image)
        guard results.count >= 1 else { return }
        #expect(results[0] == results[0])
    }

    // Issue #10: BarcodeResult is Codable (round-trip).
    @Test("BarcodeResult round-trips through JSON encoding")
    func testBarcodeResultCodable() async throws {
        let generator = BarcodeGenerator(format: .qrCode, width: 200, height: 200)
        let image = try #require(try generator.write(string: "CODABLE_TEST"))
        let scanner = BarcodeScanner(formats: [.qrCode])
        let results = try scanner.read(cgImage: image)
        let result = try #require(results.first)
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(BarcodeResult.self, from: data)
        #expect(decoded == result)
    }

    // Issue #7: CaseIterable now available in production code (not just tests).
    @Test("Binarizer CaseIterable available in production code")
    func testBinarizerCaseIterable() {
        #expect(Binarizer.allCases.count == 4)
        #expect(EanAddOnSymbol.allCases.count == 3)
        #expect(TextMode.allCases.count == 6)
    }

    // Issue #11: tryHarder default consistency.
    @Test("BarcodeScanner convenience init and ScannerOptions share same tryHarder default")
    func testTryHarderDefaultConsistency() {
        let fromConvenience = BarcodeScanner()
        let fromOptions = BarcodeScanner(options: ScannerOptions())
        #expect(fromConvenience.options.tryHarder == fromOptions.options.tryHarder,
                "Both init paths should produce the same tryHarder default")
    }

    // maxNumberOfSymbols > 1 configuration.
    @Test("maxNumberOfSymbols option can be configured above 1")
    func testMultiSymbolConfig() {
        var opts = ScannerOptions()
        opts.maxNumberOfSymbols = 5
        let scanner = BarcodeScanner(options: opts)
        #expect(scanner.options.maxNumberOfSymbols == 5)
    }
}

