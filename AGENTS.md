# Guidelines for AI Agents

Welcome to **ZxingKit**, a Swift and Objective-C++ wrapper framework for the modern [zxing-cpp](https://github.com/zxing-cpp/zxing-cpp) barcode scanning and generation library (including bundled `libzint` vector barcode rendering).

---

## Project Structure & Architecture

The codebase is organized into three primary SwiftPM targets under `Sources/`:

1. **`ZxingKit` (`Sources/ZxingKit/`)**:
   - Modern, Swift-idiomatic public layer (`BarcodeScanner`, `BarcodeGenerator`, `BarcodeResult`, `Position`, `BarcodeFormat`).
   - Provides async/await scanning methods (`readAsync`), image decoding, and format filtering.

2. **`ZXingCpp` (`Sources/ZXingCpp/`)**:
   - Objective-C++ interop bridge layer (`ZXIBarcodeReader`, `ZXIBarcodeWriter`, `ZXIReaderOptions`, `ZXIWriterOptions`, `ZXIFormat`).
   - Safely encapsulates low-level C++ pointers, std::vector, and memory ownership into Cocoa-compatible types.

3. **`ZXingCppCore` (`Sources/ZXingCppCore/`)**:
   - Core C++ engine adapted from `zxing-cpp` (`core/src`).
   - Contains symbology decoders/encoders (`qrcode`, `pdf417`, `datamatrix`, `oned`, `aztec`, `maxicode`) and embedded `libzint` for barcode vector rendering.

---

## Build & Verification Commands

When making changes to this codebase, always verify compilation and test execution:

```bash
# Build the package
swift build

# Run unit and integration tests
swift test

# Run tests and generate code coverage report (96%+ coverage target)
./scripts/coverage.sh         # Terminal summary
./scripts/coverage.sh --html  # Generate HTML report at .build/codecov/html/index.html

# Build codebase knowledge graph (excluding third-party dependencies)
codegraph build . -e third_party/
```

---

## Upstream Synchronization Guidelines (`third_party/zxing-cpp`)

The latest upstream `zxing-cpp` source and submodules live under `third_party/zxing-cpp`.
When updating the core C++ engine:
- Copy C++ core sources from `third_party/zxing-cpp/core/src` into `Sources/ZXingCppCore/`.
- Copy iOS wrapper sources from `third_party/zxing-cpp/wrappers/ios/Sources/Wrapper` into `Sources/ZXingCpp/`.
- Copy `libzint` backend files (`third_party/zxing-cpp/zint/backend/`) into `Sources/ZXingCppCore/libzint/`.
- Ensure `Version.h` is present in `Sources/ZXingCppCore/` with `ZXING_READERS` and `ZXING_WRITERS` definitions.
- Keep `BarcodeFormat` raw values in `ZxingKit.swift` 1-to-1 synchronized with `ZXIFormat` in `ZXIFormat.h`.

---

## codegraph-gen

This project maintains a codebase knowledge graph at `.codegraph/`.

### Guidelines for AI Agents (Antigravity, Claude Code, Cursor, Roo Code, etc.)

You MUST follow these rules when working in this codebase:

1. **Prioritize the Knowledge Graph**:
   - Before answering architecture, design, or codebase structure questions, you **MUST** read [.codegraph/README.md](.codegraph/README.md) to understand the system overview, god nodes, and logical community structure.
   - Use [.codegraph/components/](.codegraph/components/) and [.codegraph/nodes/](.codegraph/nodes/) to navigate component boundaries, file relationships, and symbol definitions. This is much faster and more token-efficient than reading raw source files directly.

2. **AI Architectural Insights**:
   - Check [.codegraph/README.md](.codegraph/README.md) for a section titled `AI Architectural Insights`.
   - If this section is missing, incomplete, or contains placeholders, read [.codegraph/AGENT_PROMPT.md](.codegraph/AGENT_PROMPT.md), perform a deep architectural analysis of the project, and write your report into that section. Do not overwrite other sections.

3. **Keep Graph Sync'd**:
   - Whenever you create, delete, or modify code files, you **SHOULD** remind the user to run `codegraph build .` to rebuild the knowledge graph and keep it current.
   - When running the build command, exclude irrelevant or generated directories (e.g., third-party dependencies, build folders, or documentation) using the `-e`/`--exclude` flag to keep the graph focused and clean (e.g., `codegraph build . -e third_party/`).
