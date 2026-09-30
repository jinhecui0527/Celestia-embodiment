import Combine
import Foundation
import CoreGraphics

/// Frame-rate owner of Cocoa's body on this device. The link feeds it channel
/// patches; the stage samples `frame(at:)` once per display frame.
final class PresenceEngine: ObservableObject {
    /// True while another body holds the presence lease.
    @Published var isDormant = false

    let motion = MotionParallax()
    private var mixer = ChannelMixer()
    private var lastFrame: Date?
    private(set) var current = PresenceChannels.neutral

    func apply(_ patch: ChannelPatch) {
        mixer.apply(patch)
    }

    /// Where the viewer is, in -1...1 stage coordinates (y up). Nil when unknown.
    func setViewerFocus(_ point: CGPoint?) {
        mixer.viewerFocus = point.map { (x: Double($0.x), y: Double($0.y)) }
    }

    func frame(at date: Date) -> PresenceChannels {
        let dt = lastFrame.map { date.timeIntervalSince($0) } ?? 1.0 / 60
        lastFrame = date
        var out = mixer.advance(dt: dt)
        if isDormant {
            out.attention *= 0.3
            out.mouthOpen = 0
        }
        current = out
        return out
    }
}
