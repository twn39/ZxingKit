// swift-tools-version: 5.7.1
import PackageDescription

let package = Package(
    name: "ZxingKit",
    platforms: [
        .macOS(.v13), .iOS(.v14)
    ],
    products: [
        .library(
            name: "ZxingKit",
            targets: ["ZxingKit"]
        )
    ],
    targets: [
        // C++ 核心库 (现在包含 Zint)
        .target(
            name: "ZXingCppCore",
            path: "Sources/ZXingCppCore",
            exclude: ["ZXingC.cpp", "ZXingCpp.cpp"],
            publicHeadersPath: ".",
            cSettings: [
                .define("ZINT_NO_PNG")
            ],
            cxxSettings: [
                .headerSearchPath("libzint"),
                .define("ZXING_INTERNAL"),
                .define("ZXING_USE_BUNDLED_ZINT"),
                .define("ZXING_USE_ZINT")
            ]
        ),
        // Objective-C++ iOS 封装层
        .target(
            name: "ZXingCpp",
            dependencies: ["ZXingCppCore"],
            path: "Sources/ZXingCpp",
            publicHeadersPath: ".",
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreImage"),
                .linkedFramework("CoreVideo")
            ]
        ),
        // Swift 抽象层
        .target(
            name: "ZxingKit",
            dependencies: ["ZXingCpp"],
            path: "Sources/ZxingKit"
        ),
        .testTarget(
            name: "ZxingKitTests",
            dependencies: ["ZxingKit"]
        )
    ],
    cxxLanguageStandard: .cxx20
)
