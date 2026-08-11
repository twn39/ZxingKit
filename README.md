<div align="center">

# ZxingKit

**A modern, pure-Swift wrapper for [zxing-cpp](https://github.com/zxing-cpp/zxing-cpp) — scan and generate barcodes with zero friction.**

[![CI](https://github.com/twn39/ZxingKit/actions/workflows/ci.yml/badge.svg)](https://github.com/twn39/ZxingKit/actions/workflows/ci.yml)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![SPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen)](https://swift.org/package-manager/)
[![Platform](https://img.shields.io/badge/platforms-iOS%2014%2B%20%7C%20macOS%2013%2B-blue)](https://developer.apple.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

---

ZxingKit bundles **zxing-cpp v3.0.2** and **libzint v2.13.0** directly as Swift Package sources, delivering a fully native SwiftPM experience with **zero external submodule dependencies** and **no networking required** at build time.

## ✨ Features

| Capability | Details |
|---|---|
| 📷 **Multi-format scanning** | QR Code, DataMatrix, Aztec, PDF417, EAN/UPC, Code 128, Code 39, ITF, Codabar, MaxiCode, and more (20+ formats) |
| 🖨️ **Rich generation** | `libzint` unlocks formats beyond native zxing-cpp: MaxiCode, DataBar, RMQRCode, GS1 composites, and more |
| ⚡ **Real-time camera** | Direct `CVPixelBuffer` and `CMSampleBuffer` support for AVFoundation streams with zero-copy paths |
| 🔒 **Swift 6 concurrency** | Full `Sendable` conformance, `async/await` APIs, `@unchecked Sendable` wrappers for non-Sendable Apple types |
| 🧩 **Pure Swift API** | No ObjC prefixes, no `Unmanaged<CGImage>`, no unsafe pointers — just clean, idiomatic Swift types |
| 📦 **Self-contained** | zxing-cpp and zint are vendored — no submodules, no CocoaPods, no Carthage |

## 📐 Architecture

```
┌─────────────────────────────────────────────────────┐
│              Your App / SwiftUI / UIKit              │
└───────────────────────┬─────────────────────────────┘
                        │  import ZxingKit
┌───────────────────────▼─────────────────────────────┐
│  ZxingKit  (Swift)                                  │
│  BarcodeScanner · BarcodeGenerator · BarcodeResult  │
│  ScannerOptions · BarcodeFormat · ZxingError        │
└───────────────────────┬─────────────────────────────┘
                        │  ObjC++ bridge
┌───────────────────────▼─────────────────────────────┐
│  ZXingCpp  (Objective-C++)                          │
│  ZXIBarcodeReader · ZXIBarcodeWriter                │
│  ZXIReaderOptions · ZXIFormat                       │
└──────────────┬──────────────────────────────────────┘
               │  C++20 / libzint
┌──────────────▼──────────────┐  ┌──────────────────┐
│  ZXingCppCore  (C++)        │  │  libzint  (C)    │
│  zxing-cpp v3.0.2 engine   │  │  zint v2.13.0    │
└─────────────────────────────┘  └──────────────────┘
```

## 📦 Installation

### Swift Package Manager

Add ZxingKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/twn39/ZxingKit.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["ZxingKit"]
    )
]
```

Or in Xcode: **File → Add Package Dependencies…** and paste the repository URL.

## 🚀 Usage

### Scanning — from `CGImage`

```swift
import ZxingKit

var options = ScannerOptions()
options.formats = [.qrCode, .dataMatrix, .pdf417]
options.tryHarder = true
options.tryRotate = true

let scanner = BarcodeScanner(options: options)

let cgImage: CGImage = /* your image */
let results = try scanner.read(cgImage: cgImage)

for result in results {
    print("Format: \(result.format)")
    print("Text:   \(result.text)")
    print("Corners: \(String(describing: result.position))")
}
```

### Scanning — live camera (`CMSampleBuffer`)

```swift
import ZxingKit
import AVFoundation

let scanner = BarcodeScanner()

// In AVCaptureVideoDataOutputSampleBufferDelegate:
func captureOutput(_ output: AVCaptureOutput,
                   didOutput sampleBuffer: CMSampleBuffer,
                   from connection: AVCaptureConnection) {
    let results = try? scanner.read(sampleBuffer: sampleBuffer)
    results?.forEach { print($0.text) }
}
```

### Async scanning

```swift
import ZxingKit

let scanner = BarcodeScanner()
let ciImage: CIImage = /* your image */

// Runs on a background task — safe to call from the main actor
let results = try await scanner.readAsync(ciImage: ciImage)
```

### Generating a barcode

```swift
import ZxingKit

// QR Code
let qrGen = BarcodeGenerator(format: .qrCode, width: 512, height: 512)
if let image: CGImage = try qrGen.write(string: "https://github.com/twn39/ZxingKit") {
    // use image in UIImageView / NSImageView / SwiftUI Image(decorative: image, scale: 1)
}

// MaxiCode (requires bundled libzint)
let maxiGen = BarcodeGenerator(format: .maxicode, width: 300, height: 300)
if let image = try maxiGen.write(string: "[)>\u001E01\u001D9612345\u001D001\u001D001\u001D80012345678") {
    // use image
}

// Async generation
let image = try await qrGen.writeAsync(string: "Hello, ZxingKit!")
```

### Supported Barcode Formats

<details>
<summary>Click to expand full format list</summary>

**Scan & Generate**

`aztec` · `codabar` · `code39` · `code93` · `code128` · `dataBar` · `dataBarExpanded` · `dataMatrix` · `ean8` · `ean13` · `itf` · `maxicode` · `pdf417` · `qrCode` · `upca` · `upce`

**Scan Only** (via zxing-cpp)

`code39Extended` · `microPDF417` · `microQRCode` · `rmQRCode`

**Generate Only** (via libzint extras)

`dataBarLimited` · `dataBarStackedOmni` · GS1 composite variants

</details>

## ⚙️ Requirements

| Requirement | Minimum Version |
|---|---|
| Swift | 6.0+ |
| iOS | 14.0+ |
| macOS | 13.0+ |
| Xcode | 16.0+ |

## 🔬 Running Tests & Coverage

```bash
# Run all tests
swift test

# Generate code coverage report (target: 96%+)
./scripts/coverage.sh            # terminal summary
./scripts/coverage.sh --html     # HTML report → .build/codecov/html/index.html
```

CI runs on every push and PR, testing against **Swift 6.0, 6.1, and 6.2** in parallel:

| Xcode | Swift | Runner |
|-------|-------|--------|
| 16.0  | 6.0   | macos-15 |
| 16.3  | 6.1   | macos-15 |
| 16.4  | 6.2   | macos-15 |

## 🔄 Upgrading Upstream Sources

To update the bundled zxing-cpp or zint to a newer version:

1. **zxing-cpp core** — copy `zxing-cpp/core/src` → `Sources/ZXingCppCore/` (preserve the `libzint/` subdirectory).
2. **libzint backend** — copy `zint/backend/` → `Sources/ZXingCppCore/libzint/`.
3. **ObjC++ wrapper** — copy `zxing-cpp/wrappers/ios/Sources/Wrapper` → `Sources/ZXingCpp/`.
4. **Version.h** — update `Sources/ZXingCppCore/Version.h` if `Version.h.in` changed upstream.
5. **Format sync** — if new barcode formats were added, keep `BarcodeFormat` (Swift) and `ZXIFormat` / `ZXIFormatHelper` (ObjC++) in 1-to-1 sync.
6. **Verify** — run `swift test` to confirm everything compiles and all 32+ tests pass.

### Current Bundled Versions

| Library | Version | Notes |
|---------|---------|-------|
| zxing-cpp | v3.0.2 | Writer uses `CreateBarcodeFromText` API |
| zint | v2.13.0+ (commit `55541e1`) | `ZINT_NO_PNG` — raw matrix computation only |

## 📄 License

ZxingKit is released under the **MIT License**. See [LICENSE](LICENSE) for details.

The bundled libraries retain their respective licenses:
- **zxing-cpp**: [Apache 2.0](https://github.com/zxing-cpp/zxing-cpp/blob/master/LICENSE)
- **zint**: [GPL-3.0](https://sourceforge.net/p/zint/code/HEAD/tree/trunk/LICENSE)