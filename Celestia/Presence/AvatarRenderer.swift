import SwiftUI

/// Draws Cocoa as layered 2D art with per-layer depth ("2D-to-mesh" MVP).
///
/// Every layer has a depth; tilt parallax and head yaw/pitch move deeper layers
/// less than shallow ones, so the flat art reads as a turning head. Blink, gaze,
/// mouth, brows and breath deform individual layers continuously.
struct AvatarRenderer {
    let pack: AvatarPack
    var accent: Color

    private enum Depth {
        static let halo = -1.1
        static let hairBack = -0.4
        static let body = -0.25
        static let neck = -0.15
        static let face = 0.0
        static let blush = 0.06
        static let mouth = 0.08
        static let eyes = 0.1
        static let nose = 0.12
        static let brows = 0.14
        static let sideLocks = 0.18
        static let bangs = 0.24
    }

    private enum Palette {
        static let skinLight = Color(red: 0.99, green: 0.89, blue: 0.83)
        static let skinShade = Color(red: 0.93, green: 0.76, blue: 0.68)
        static let hairTop = Color(red: 0.40, green: 0.25, blue: 0.20)
        static let hairBottom = Color(red: 0.19, green: 0.11, blue: 0.10)
        static let lash = Color(red: 0.20, green: 0.11, blue: 0.10)
        static let irisTop = Color(red: 0.45, green: 0.22, blue: 0.12)
        static let irisBottom = Color(red: 0.93, green: 0.64, blue: 0.36)
        static let sclera = Color(red: 1.0, green: 0.98, blue: 0.96)
        static let lip = Color(red: 0.55, green: 0.20, blue: 0.24)
        static let tongue = Color(red: 0.86, green: 0.45, blue: 0.48)
        static let cloth = Color(red: 0.93, green: 0.91, blue: 0.96)
        static let clothShade = Color(red: 0.74, green: 0.72, blue: 0.82)
    }

    func draw(_ c: PresenceChannels, parallax: CGVector, dormant: Bool, in context: inout GraphicsContext, size: CGSize) {
        let unit = min(size.width * 0.26, size.height * 0.24)
        var ctx = context
        ctx.translateBy(x: size.width / 2, y: size.height * 0.41)
        ctx.scaleBy(x: unit, y: unit)
        if dormant { ctx.opacity = 0.72 }

        let turn = CGVector(
            dx: parallax.dx * 0.16 + c.headYaw * 0.38,
            dy: -parallax.dy * 0.1 - c.headPitch * 0.26
        )
        func layer(_ depth: Double, from base: GraphicsContext, _ body: (inout GraphicsContext) -> Void) {
            var l = base
            l.translateBy(x: turn.dx * depth, y: turn.dy * depth)
            body(&l)
        }

        drawHalo(c, in: ctx, turn: turn)

        var torso = ctx
        torso.translateBy(x: 0, y: -c.breath * 0.035)
        layer(Depth.hairBack, from: torso) { drawHairBack(in: &$0) }
        layer(Depth.neck, from: torso) { drawNeck(in: &$0) }
        layer(Depth.body, from: torso) { l in
            l.translateBy(x: 0, y: -c.breath * 0.015)
            drawBody(in: &l)
        }

        var head = torso
        head.translateBy(x: 0, y: 0.9 - c.breath * 0.012 + c.headPitch * 0.04)
        head.rotate(by: .radians(c.headRoll * 0.14))
        head.translateBy(x: 0, y: -0.9)
        head.scaleBy(x: 1 - abs(c.headYaw) * 0.05, y: 1)

        layer(Depth.face, from: head) { drawFace(in: &$0) }
        layer(Depth.blush, from: head) { drawBlush(c, in: &$0) }
        layer(Depth.mouth, from: head) { drawMouth(c, in: &$0) }
        layer(Depth.nose, from: head) { drawNose(in: &$0) }
        layer(Depth.eyes, from: head) { drawEyes(c, in: &$0) }
        layer(Depth.brows, from: head) { drawBrows(c, in: &$0) }
        layer(Depth.sideLocks, from: head) { drawSideLocks(in: &$0) }
        layer(Depth.bangs, from: head) { drawBangs(c, in: &$0) }
    }

    // MARK: Layers

    private func drawHalo(_ c: PresenceChannels, in ctx: GraphicsContext, turn: CGVector) {
        var l = ctx
        l.translateBy(x: turn.dx * Depth.halo, y: turn.dy * Depth.halo)
        let radius = 2.1 + c.breath * 0.06 + c.energy * 0.15
        let glow = accent.opacity(0.18 + 0.22 * c.warmth)
        l.fill(
            Path(ellipseIn: CGRect(x: -radius, y: -radius - 0.1, width: radius * 2, height: radius * 2)),
            with: .radialGradient(Gradient(colors: [glow, glow.opacity(0.05), .clear]),
                                  center: CGPoint(x: 0, y: -0.1), startRadius: 0.2, endRadius: radius)
        )
    }

    private func drawHairBack(in ctx: inout GraphicsContext) {
        if let image = pack.image(.hairBack) { ctx.draw(image, in: AvatarPack.canvas); return }
        var p = Path()
        p.move(to: pt(0, -1.34))
        p.addCurve(to: pt(1.2, -0.3), control1: pt(0.78, -1.36), control2: pt(1.23, -0.92))
        p.addCurve(to: pt(1.32, 1.95), control1: pt(1.2, 0.55), control2: pt(1.46, 1.35))
        p.addCurve(to: pt(-1.32, 1.95), control1: pt(0.5, 2.15), control2: pt(-0.5, 2.15))
        p.addCurve(to: pt(-1.2, -0.3), control1: pt(-1.46, 1.35), control2: pt(-1.2, 0.55))
        p.addCurve(to: pt(0, -1.34), control1: pt(-1.23, -0.92), control2: pt(-0.78, -1.36))
        ctx.fill(p, with: hairGradient(top: -1.34, bottom: 2.1))
    }

    private func drawNeck(in ctx: inout GraphicsContext) {
        let neck = Path(roundedRect: CGRect(x: -0.24, y: 0.55, width: 0.48, height: 0.95), cornerRadius: 0.2)
        ctx.fill(neck, with: .linearGradient(Gradient(colors: [Palette.skinShade, Palette.skinLight]),
                                             startPoint: pt(0, 0.6), endPoint: pt(0, 1.4)))
    }

    private func drawBody(in ctx: inout GraphicsContext) {
        if let image = pack.image(.body) { ctx.draw(image, in: AvatarPack.canvas); return }
        var p = Path()
        p.move(to: pt(-1.62, 1.8))
        p.addCurve(to: pt(-0.32, 1.24), control1: pt(-1.2, 1.46), control2: pt(-0.62, 1.3))
        p.addLine(to: pt(0, 1.64))
        p.addLine(to: pt(0.32, 1.24))
        p.addCurve(to: pt(1.62, 1.8), control1: pt(0.62, 1.3), control2: pt(1.2, 1.46))
        p.addLine(to: pt(1.95, 3.4))
        p.addLine(to: pt(-1.95, 3.4))
        p.closeSubpath()
        ctx.fill(p, with: .linearGradient(Gradient(colors: [Palette.cloth, Palette.clothShade]),
                                          startPoint: pt(0, 1.2), endPoint: pt(0, 3.2)))

        var collar = Path()
        collar.move(to: pt(-0.36, 1.22))
        collar.addLine(to: pt(0, 1.66))
        collar.addLine(to: pt(0.36, 1.22))
        ctx.stroke(collar, with: .color(accent.opacity(0.8)), style: StrokeStyle(lineWidth: 0.045, lineCap: .round, lineJoin: .round))
    }

    private func drawFace(in ctx: inout GraphicsContext) {
        if let image = pack.image(.face) { ctx.draw(image, in: AvatarPack.canvas); return }
        ctx.fill(Self.facePath, with: .linearGradient(Gradient(colors: [Palette.skinLight, Palette.skinLight, Palette.skinShade]),
                                                      startPoint: pt(0, -0.9), endPoint: pt(0, 1.0)))
    }

    private func drawBlush(_ c: PresenceChannels, in ctx: inout GraphicsContext) {
        let alpha = 0.08 + 0.32 * c.warmth
        for side in [-1.0, 1.0] {
            let center = pt(side * 0.5, 0.36)
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - 0.2, y: center.y - 0.11, width: 0.4, height: 0.22)),
                     with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.55, blue: 0.6).opacity(alpha), .clear]),
                                           center: center, startRadius: 0, endRadius: 0.2))
        }
    }

    private func drawNose(in ctx: inout GraphicsContext) {
        var p = Path()
        p.move(to: pt(0.01, 0.26))
        p.addQuadCurve(to: pt(-0.03, 0.33), control: pt(0.0, 0.31))
        ctx.stroke(p, with: .color(Palette.skinShade.opacity(0.9)), style: StrokeStyle(lineWidth: 0.025, lineCap: .round))
    }

    private func drawEyes(_ c: PresenceChannels, in ctx: inout GraphicsContext) {
        let gaze = CGVector(dx: c.gazeX * 0.075, dy: -c.gazeY * 0.055)
        if let open = pack.image(.eyesOpen) {
            var o = ctx
            o.opacity *= 1 - c.blink
            o.translateBy(x: gaze.dx, y: gaze.dy)
            o.draw(open, in: AvatarPack.canvas)
            if let closed = pack.image(.eyesClosed) {
                var cl = ctx
                cl.opacity *= c.blink
                cl.draw(closed, in: AvatarPack.canvas)
            }
            return
        }

        let openness = max(0, 1 - c.blink) * (1 + max(0, c.browRaise) * 0.12)
        for side in [-1.0, 1.0] {
            let center = pt(side * 0.36, 0.06)
            let width = 0.34
            let fullHeight = 0.32
            let height = fullHeight * openness
            let bottom = center.y + fullHeight * 0.4
            let eyeRect = CGRect(x: center.x - width / 2, y: bottom - height, width: width, height: max(height, 0.001))

            if openness > 0.08 {
                let sclera = Path(ellipseIn: eyeRect)
                ctx.fill(sclera, with: .color(Palette.sclera))

                var inner = ctx
                inner.clip(to: sclera)
                let irisCenter = pt(center.x + gaze.dx, center.y + 0.02 + gaze.dy)
                let r = 0.125
                inner.fill(Path(ellipseIn: CGRect(x: irisCenter.x - r, y: irisCenter.y - r * 1.1, width: r * 2, height: r * 2.2)),
                           with: .linearGradient(Gradient(colors: [Palette.irisTop, Palette.irisBottom]),
                                                 startPoint: pt(0, irisCenter.y - r), endPoint: pt(0, irisCenter.y + r)))
                let pr = 0.05 + 0.012 * (1 - c.energy)
                inner.fill(Path(ellipseIn: CGRect(x: irisCenter.x - pr, y: irisCenter.y - pr * 1.1, width: pr * 2, height: pr * 2.2)),
                           with: .color(Color(red: 0.14, green: 0.06, blue: 0.05)))
                inner.fill(Path(ellipseIn: CGRect(x: irisCenter.x - 0.075, y: irisCenter.y - 0.1, width: 0.06, height: 0.06)),
                           with: .color(.white.opacity(0.95)))
                inner.fill(Path(ellipseIn: CGRect(x: irisCenter.x + 0.035, y: irisCenter.y + 0.035, width: 0.03, height: 0.03)),
                           with: .color(.white.opacity(0.7)))
                // Upper lid shadow.
                inner.fill(Path(CGRect(x: eyeRect.minX, y: eyeRect.minY, width: width, height: 0.05)),
                           with: .color(Palette.lash.opacity(0.18)))

                var lash = Path()
                lash.move(to: pt(center.x - side * width * 0.52, eyeRect.midY + 0.02))
                lash.addQuadCurve(to: pt(center.x + side * width * 0.56, eyeRect.midY - height * 0.1),
                                  control: pt(center.x, eyeRect.minY - 0.035))
                lash.addLine(to: pt(center.x + side * width * 0.64, eyeRect.midY - height * 0.28))
                ctx.stroke(lash, with: .color(Palette.lash), style: StrokeStyle(lineWidth: 0.045, lineCap: .round, lineJoin: .round))
            } else {
                var closed = Path()
                closed.move(to: pt(center.x - width * 0.5, bottom - 0.03))
                closed.addQuadCurve(to: pt(center.x + width * 0.5, bottom - 0.03), control: pt(center.x, bottom + 0.04))
                ctx.stroke(closed, with: .color(Palette.lash), style: StrokeStyle(lineWidth: 0.04, lineCap: .round))
            }
        }
    }

    private func drawBrows(_ c: PresenceChannels, in ctx: inout GraphicsContext) {
        if let image = pack.image(.brows) {
            var l = ctx
            l.translateBy(x: 0, y: -c.browRaise * 0.06)
            l.draw(image, in: AvatarPack.canvas)
            return
        }
        let lift = c.browRaise * 0.07
        for side in [-1.0, 1.0] {
            var p = Path()
            let innerY = -0.26 - lift + max(0, -c.browRaise) * 0.03
            p.move(to: pt(side * 0.2, innerY))
            p.addQuadCurve(to: pt(side * 0.52, -0.25 - lift * 0.7), control: pt(side * 0.38, -0.33 - lift))
            ctx.stroke(p, with: .color(Palette.hairTop.opacity(0.85)), style: StrokeStyle(lineWidth: 0.035, lineCap: .round))
        }
    }

    private func drawMouth(_ c: PresenceChannels, in ctx: inout GraphicsContext) {
        let open = c.mouthOpen
        if open > 0.04, let image = pack.image(.mouthOpen) {
            var o = ctx
            o.opacity *= min(1, open * 1.5)
            o.draw(image, in: AvatarPack.canvas)
            if let closed = pack.image(.mouthClosed) {
                var cl = ctx
                cl.opacity *= max(0, 1 - open * 1.5)
                cl.draw(closed, in: AvatarPack.canvas)
            }
            return
        } else if let closed = pack.image(.mouthClosed) {
            ctx.draw(closed, in: AvatarPack.canvas)
            return
        }

        let y = 0.54
        let halfWidth = 0.1 + 0.03 * max(0, c.mouthSmile) + 0.02 * open
        let corner = -0.05 * c.mouthSmile
        let left = pt(-halfWidth, y + corner)
        let right = pt(halfWidth, y + corner)

        if open < 0.05 {
            var p = Path()
            p.move(to: left)
            p.addQuadCurve(to: right, control: pt(0, y + 0.03 * c.mouthSmile + 0.01))
            ctx.stroke(p, with: .color(Palette.lip), style: StrokeStyle(lineWidth: 0.03, lineCap: .round))
            return
        }

        let depth = 0.04 + open * 0.2
        var p = Path()
        p.move(to: left)
        p.addQuadCurve(to: right, control: pt(0, y - 0.015 + 0.01 * c.mouthSmile))
        p.addQuadCurve(to: left, control: pt(0, y + depth * 1.6))
        p.closeSubpath()
        ctx.fill(p, with: .color(Palette.lip))

        var inner = ctx
        inner.clip(to: p)
        inner.fill(Path(ellipseIn: CGRect(x: -halfWidth * 0.6, y: y + depth * 0.45, width: halfWidth * 1.2, height: depth)),
                   with: .color(Palette.tongue))
    }

    private func drawSideLocks(in ctx: inout GraphicsContext) {
        for side in [-1.0, 1.0] {
            var p = Path()
            p.move(to: pt(side * 0.98, -0.45))
            p.addCurve(to: pt(side * 0.84, 0.95), control1: pt(side * 1.08, 0.1), control2: pt(side * 1.0, 0.6))
            p.addCurve(to: pt(side * 0.66, 0.15), control1: pt(side * 0.72, 0.7), control2: pt(side * 0.64, 0.42))
            p.addCurve(to: pt(side * 0.8, -0.4), control1: pt(side * 0.68, -0.1), control2: pt(side * 0.74, -0.3))
            p.closeSubpath()
            ctx.fill(p, with: hairGradient(top: -0.45, bottom: 0.95))
        }
    }

    private func drawBangs(_ c: PresenceChannels, in ctx: inout GraphicsContext) {
        if let image = pack.image(.bangs) { ctx.draw(image, in: AvatarPack.canvas); return }
        var p = Path()
        p.move(to: pt(-0.99, -0.2))
        p.addCurve(to: pt(0, -1.3), control1: pt(-1.06, -0.96), control2: pt(-0.56, -1.32))
        p.addCurve(to: pt(0.99, -0.2), control1: pt(0.56, -1.32), control2: pt(1.06, -0.96))
        p.addCurve(to: pt(0.62, -0.42), control1: pt(0.9, -0.46), control2: pt(0.76, -0.52))
        p.addCurve(to: pt(0.3, -0.3), control1: pt(0.55, -0.36), control2: pt(0.42, -0.28))
        p.addCurve(to: pt(0.05, -0.52), control1: pt(0.2, -0.34), control2: pt(0.1, -0.44))
        p.addCurve(to: pt(-0.25, -0.28), control1: pt(-0.02, -0.4), control2: pt(-0.12, -0.28))
        p.addCurve(to: pt(-0.6, -0.46), control1: pt(-0.38, -0.3), control2: pt(-0.5, -0.36))
        p.addCurve(to: pt(-0.99, -0.2), control1: pt(-0.76, -0.54), control2: pt(-0.9, -0.46))
        p.closeSubpath()
        ctx.fill(p, with: hairGradient(top: -1.3, bottom: -0.2))

        var sheen = Path()
        sheen.addArc(center: pt(0, -0.35), radius: 0.8, startAngle: .degrees(-150), endAngle: .degrees(-40), clockwise: false)
        ctx.stroke(sheen, with: .color(.white.opacity(0.1 + 0.06 * c.warmth)), style: StrokeStyle(lineWidth: 0.07, lineCap: .round))

        var ahoge = Path()
        ahoge.move(to: pt(0.02, -1.26))
        ahoge.addCurve(to: pt(0.22, -1.52), control1: pt(-0.05, -1.45), control2: pt(0.1, -1.6 - c.energy * 0.05))
        ctx.stroke(ahoge, with: .color(Palette.hairTop), style: StrokeStyle(lineWidth: 0.045, lineCap: .round))
    }

    // MARK: Helpers

    private static let facePath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -1.0))
        p.addCurve(to: CGPoint(x: 0.86, y: -0.15), control1: CGPoint(x: 0.5, y: -1.0), control2: CGPoint(x: 0.88, y: -0.62))
        p.addCurve(to: CGPoint(x: 0, y: 0.95), control1: CGPoint(x: 0.84, y: 0.4), control2: CGPoint(x: 0.35, y: 0.9))
        p.addCurve(to: CGPoint(x: -0.86, y: -0.15), control1: CGPoint(x: -0.35, y: 0.9), control2: CGPoint(x: -0.84, y: 0.4))
        p.addCurve(to: CGPoint(x: 0, y: -1.0), control1: CGPoint(x: -0.88, y: -0.62), control2: CGPoint(x: -0.5, y: -1.0))
        p.closeSubpath()
        return p
    }()

    private func hairGradient(top: Double, bottom: Double) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [Palette.hairTop, Palette.hairBottom]), startPoint: pt(0, top), endPoint: pt(0, bottom))
    }

    private func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
}
