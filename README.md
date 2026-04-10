# ZxingKit

ZxingKit is a modern, lightweight, and pure Swift wrapper for the popular C++ barcode scanning and generation library, [zxing-cpp](https://github.com/zxing-cpp/zxing-cpp). 

This library packages the essential `zxing-cpp` core (version 3.0.2) along with its C-based dependency, [zint](https://github.com/zint/zint) (version 2.13.0+), directly as Swift Package sources. This ensures a fully native SwiftPM experience with **zero external submodule dependencies** and **no networking required** during a build.

## Features

*   **Comprehensive Barcode Reading:** Supports reading over 20 different barcode formats (QR Code, DataMatrix, Aztec, PDF417, EAN/UPC, Code128, etc.).
*   **Comprehensive Barcode Generation:** By directly compiling `libzint` within the target, ZxingKit gains the ability to generate a vast array of 1D and 2D barcodes that the base `zxing-cpp` cannot write natively (e.g., MaxiCode, DataBar families, RMQRCode).
*   **Modern Swift API:** Forget about Objective-C prefixed enums, `Unmanaged<CGImage>`, or unsafe memory handling. ZxingKit provides clean, native Swift types (`BarcodeFormat`, `BarcodeResult`, `ScannerOptions`).
*   **High Performance:** Supports real-time scanning directly from `CVPixelBuffer` for AVFoundation camera streams.
*   **Cross-Platform:** Built for iOS 14.0+ and macOS 13.0+.
*   **Self-Contained:** Source code for `zxing-cpp` and `zint` is vendored directly inside this package to reduce build friction and bloated repositories.

## Installation

As this is a local Swift Package inside the `Vendors` folder of your workspace, it is already integrated into the `barcode.xcodeproj` build phases. 

You can simply import it anywhere in your Swift files:

```swift
import ZxingKit
```

## Technical Details & Architecture

ZxingKit is divided into three core targets within the Swift Package Manager:

1.  **ZXingCppZint (C)**: Contains the stripped-down core backend of the `zint` library. It ignores UI-heavy dependencies like `libpng` (`ZINT_NO_PNG`) to ensure it only performs raw barcode matrix calculation.
2.  **ZXingCppCore (C++)**: The `zxing-cpp` version `3.0.2` core library. It is compiled with `-DZXING_USE_BUNDLED_ZINT` to ensure barcode generation requests for formats like MaxiCode or Aztec are correctly routed to the bundled Zint backend.
3.  **ZXingCpp (Objective-C++)**: A translation layer that bridges the modern C++20 features of `zxing-cpp` to Objective-C, enabling interoperability with Swift. It heavily utilizes `CGImage`, `CIImage`, and `CVPixelBuffer`.
4.  **ZxingKit (Swift)**: The top-level Swift API that hides all the underlying bridging mechanics. 

## Usage

### 1. Scanning a Barcode (from `CGImage` or `CVPixelBuffer`)

```swift
import ZxingKit
import CoreVideo

// 1. Initialize a scanner with optional configuration
var options = ScannerOptions()
options.formats = [.qrCode, .code128, .ean13]
options.tryHarder = true
options.tryRotate = true
options.binarizer = .localAverage

let scanner = BarcodeScanner(options: options)

// 2. Scan a pixel buffer (e.g., from camera)
do {
    let pixelBuffer: CVPixelBuffer = ... 
    let results = try scanner.read(pixelBuffer: pixelBuffer)
    
    for result in results {
        print("Found \(result.format) with text: \(result.text)")
        print("Corners: \(result.position?.topLeft) to \(result.position?.bottomRight)")
    }
} catch {
    print("Scanning failed: \(error)")
}
```

### 2. Generating a Barcode (Powered by Zint & ZXing)

Generating a barcode is as simple as providing the format and the text. Since `zint` is bundled, you can generate complex codes like `MaxiCode`.

```swift
import ZxingKit
import CoreGraphics

// Generate a MaxiCode
let generator = BarcodeGenerator(format: .maxicode, width: 300, height: 300)

do {
    // Generate a CGImage directly
    if let image: CGImage = try generator.write(string: "[)>*01*9612345*001*001*80012345678") {
        // Use the CGImage in your SwiftUI Image or UIImageView
        // Image(decorative: image, scale: 1.0)
    }
} catch {
    print("Generation failed: \(error)")
}
```

## Maintenance & Upgrades

If you ever need to upgrade the underlying `zxing-cpp` or `zint` sources, follow these specific steps to ensure the bundled architecture remains intact:

1. **Update ZXing-CPP Core**: 
   - Replace the `.cpp` and `.h` files inside `Sources/ZXingCppCore` with the newer release from `zxing-cpp/core/src`.
   - **Do not** overwrite or delete the `libzint` folder within this directory.
2. **Update Zint Backend**: 
   - Replace the `.c` and `.h` files inside `Sources/ZXingCppCore/libzint` with the newer release from `zint/backend` (or the specific commit referenced by `zxing-cpp`).
3. **Handle Exclusions & Wrappers**:
   - Ensure that `ZXingC.cpp` and `ZXingCpp.cpp` are excluded in `Package.swift` (as they conflict with our Objective-C++ wrappers).
   - If new barcode formats are added in the C++ core, update `BarcodeFormat` in `ZxingKit.swift` and `ZXIFormat` / `ZXIFormatHelper` in `Sources/ZXingCpp/ZXIFormat.h`.
4. **Update Version**: 
   - Update `Version.h` manually if the `Version.h.in` template in the C++ core changes.
5. **Verify Build**: 
   - Run `swift test` within the `Vendors/ZxingKit` directory to ensure the Objective-C++ wrappers (`Sources/ZXingCpp`) still compile against the new C++ API.

### Current Version Information
- **zxing-cpp**: `v3.0.2`
- **zint**: `v2.13.0+` (Commit: `55541e139e62b9209b71cd9b0ba9010cec28b1d9`)
- **Integration Note**: The `zxing-cpp` writer wrapper was heavily modified to use the newer `CreateBarcodeFromText` API instead of the deprecated `MultiFormatWriter` to ensure `zint` features (like MaxiCode generation) are accessible from Swift.