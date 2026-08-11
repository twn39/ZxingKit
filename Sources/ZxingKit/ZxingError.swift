import Foundation

public enum ZxingError: Error, LocalizedError, Sendable {
    case unreadableImage
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unreadableImage: return "Failed to process the image for reading."
        case .generationFailed(let message): return "Barcode generation failed: \(message)"
        }
    }
}
