import SwiftUI
import UIKit

/// A 2D art pack: one PNG per layer, all exported on the same canvas (the usual
/// PSD-to-layers workflow). Missing layers fall back to the built-in vector art,
/// so an artist can replace the avatar one layer at a time.
///
/// Add images to the asset catalog under these names (e.g. `cocoa/face`).
struct AvatarPack {
    enum Layer: String, CaseIterable {
        case hairBack = "hair_back"
        case body
        case face
        case eyesOpen = "eyes_open"
        case eyesClosed = "eyes_closed"
        case brows
        case mouthClosed = "mouth_closed"
        case mouthOpen = "mouth_open"
        case bangs
    }

    /// Canvas every layer image is drawn into, in avatar units (head ≈ 2 units wide,
    /// origin at the face center, y down).
    static let canvas = CGRect(x: -2, y: -1.6, width: 4, height: 4.8)

    let name: String
    private let images: [Layer: Image]

    init(name: String = "cocoa") {
        self.name = name
        var found: [Layer: Image] = [:]
        for layer in Layer.allCases {
            if let image = UIImage(named: "\(name)/\(layer.rawValue)") {
                found[layer] = Image(uiImage: image)
            }
        }
        images = found
    }

    func image(_ layer: Layer) -> Image? { images[layer] }

    var isVectorFallback: Bool { images.isEmpty }
}
