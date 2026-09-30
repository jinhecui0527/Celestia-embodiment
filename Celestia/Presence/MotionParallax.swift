import CoreMotion
import UIKit

/// Turns small iPad tilts into a parallax vector in -1...1. The reference attitude
/// slowly follows the device, so holding the iPad at any angle settles back to
/// center and only *movement* shifts the layers.
final class MotionParallax {
    private let manager = CMMotionManager()
    private var reference: (roll: Double, pitch: Double)?
    private var smoothed = CGVector.zero
    private var lastSample = Date()

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates()
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        reference = nil
    }

    func sample(orientation: UIInterfaceOrientation) -> CGVector {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastSample), 0.1)
        lastSample = now

        guard let attitude = manager.deviceMotion?.attitude else {
            smoothed = CGVector(dx: smoothed.dx * 0.9, dy: smoothed.dy * 0.9)
            return smoothed
        }

        var roll = attitude.roll
        var pitch = attitude.pitch
        switch orientation {
        case .landscapeLeft: (roll, pitch) = (-pitch, roll)
        case .landscapeRight: (roll, pitch) = (pitch, -roll)
        case .portraitUpsideDown: (roll, pitch) = (-roll, -pitch)
        default: break
        }

        var ref = reference ?? (roll, pitch)
        let follow = 1 - exp(-dt / 3.5)
        ref.roll += (roll - ref.roll) * follow
        ref.pitch += (pitch - ref.pitch) * follow
        reference = ref

        let target = CGVector(
            dx: max(-1, min(1, (roll - ref.roll) * 3.2)),
            dy: max(-1, min(1, (pitch - ref.pitch) * 3.2))
        )
        let k = 1 - exp(-dt / 0.08)
        smoothed.dx += (target.dx - smoothed.dx) * k
        smoothed.dy += (target.dy - smoothed.dy) * k
        return smoothed
    }
}
