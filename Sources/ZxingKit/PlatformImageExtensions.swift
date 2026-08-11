import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit

extension BarcodeScanner {
    /// Scans a `UIImage` for barcodes.
    /// - Parameters:
    ///   - image: The `UIImage` to scan.
    ///   - roi: Optional Region of Interest (ROI) rectangle.
    /// - Returns: An array of detected ``BarcodeResult``.
    public func read(image: UIImage, roi: CGRect? = nil) throws -> [BarcodeResult] {
        guard let cgImage = image.cgImage else {
            if let ciImage = image.ciImage {
                return try read(ciImage: ciImage, roi: roi)
            }
            throw ZxingError.unreadableImage
        }
        return try read(cgImage: cgImage, roi: roi)
    }

    /// Asynchronously scans a `UIImage` for barcodes.
    /// - Parameters:
    ///   - image: The `UIImage` to scan.
    ///   - roi: Optional Region of Interest (ROI) rectangle.
    /// - Returns: An array of detected ``BarcodeResult``.
    public func readAsync(image: UIImage, roi: CGRect? = nil) async throws -> [BarcodeResult] {
        if let cgImage = image.cgImage {
            return try await readAsync(cgImage: cgImage, roi: roi)
        } else if let ciImage = image.ciImage {
            return try await readAsync(ciImage: ciImage, roi: roi)
        }
        throw ZxingError.unreadableImage
    }
}

extension BarcodeGenerator {
    /// Generates a barcode as a native `UIImage`.
    /// - Parameter string: The string content to encode.
    /// - Returns: A `UIImage` containing the generated barcode, or `nil` if rendering fails.
    public func writeImage(string: String) throws -> UIImage? {
        guard let cgImage = try write(string: string) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Generates a barcode as a native `UIImage`.
    /// - Parameter data: The raw byte data to encode.
    /// - Returns: A `UIImage` containing the generated barcode, or `nil` if rendering fails.
    public func writeImage(data: Data) throws -> UIImage? {
        guard let cgImage = try write(data: data) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Asynchronously generates a barcode as a native `UIImage`.
    /// - Parameter string: The string content to encode.
    /// - Returns: A `UIImage` containing the generated barcode, or `nil` if rendering fails.
    public func writeImageAsync(string: String) async throws -> UIImage? {
        guard let cgImage = try await writeAsync(string: string) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Asynchronously generates a barcode as a native `UIImage`.
    /// - Parameter data: The raw byte data to encode.
    /// - Returns: A `UIImage` containing the generated barcode, or `nil` if rendering fails.
    public func writeImageAsync(data: Data) async throws -> UIImage? {
        guard let cgImage = try await writeAsync(data: data) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

extension BarcodeScanner {
    /// Scans an `NSImage` for barcodes.
    /// - Parameters:
    ///   - image: The `NSImage` to scan.
    ///   - roi: Optional Region of Interest (ROI) rectangle.
    /// - Returns: An array of detected ``BarcodeResult``.
    public func read(image: NSImage, roi: CGRect? = nil) throws -> [BarcodeResult] {
        var imageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        guard let cgImage = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else {
            throw ZxingError.unreadableImage
        }
        return try read(cgImage: cgImage, roi: roi)
    }

    /// Asynchronously scans an `NSImage` for barcodes.
    /// - Parameters:
    ///   - image: The `NSImage` to scan.
    ///   - roi: Optional Region of Interest (ROI) rectangle.
    /// - Returns: An array of detected ``BarcodeResult``.
    public func readAsync(image: NSImage, roi: CGRect? = nil) async throws -> [BarcodeResult] {
        var imageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        guard let cgImage = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else {
            throw ZxingError.unreadableImage
        }
        return try await readAsync(cgImage: cgImage, roi: roi)
    }
}

extension BarcodeGenerator {
    /// Generates a barcode as a native `NSImage`.
    /// - Parameter string: The string content to encode.
    /// - Returns: An `NSImage` containing the generated barcode, or `nil` if rendering fails.
    public func writeImage(string: String) throws -> NSImage? {
        guard let cgImage = try write(string: string) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Generates a barcode as a native `NSImage`.
    /// - Parameter data: The raw byte data to encode.
    /// - Returns: An `NSImage` containing the generated barcode, or `nil` if rendering fails.
    public func writeImage(data: Data) throws -> NSImage? {
        guard let cgImage = try write(data: data) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Asynchronously generates a barcode as a native `NSImage`.
    /// - Parameter string: The string content to encode.
    /// - Returns: An `NSImage` containing the generated barcode, or `nil` if rendering fails.
    public func writeImageAsync(string: String) async throws -> NSImage? {
        guard let cgImage = try await writeAsync(string: string) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Asynchronously generates a barcode as a native `NSImage`.
    /// - Parameter data: The raw byte data to encode.
    /// - Returns: An `NSImage` containing the generated barcode, or `nil` if rendering fails.
    public func writeImageAsync(data: Data) async throws -> NSImage? {
        guard let cgImage = try await writeAsync(data: data) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
#endif
