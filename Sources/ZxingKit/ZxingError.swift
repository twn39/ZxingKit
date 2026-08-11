import Foundation

/// Errors that can occur during barcode scanning or generation.
public enum ZxingError: Error, LocalizedError, Sendable {
    /// Failed to read or process the provided image buffer.
    case unreadableImage
    /// Barcode generation failed with a specific message.
    case generationFailed(String)

    /// A localized description explaining the cause of the error.
    public var errorDescription: String? {
        switch self {
        case .unreadableImage: return "Failed to process the image for reading."
        case .generationFailed(let message): return "Barcode generation failed: \(message)"
        }
    }
}
