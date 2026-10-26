import SwiftUI

/// The illustrated landscape behind the clock. Drawn in code (no image assets),
/// so it can follow the real sun, moon and season smoothly.
struct NatureScene: View {
    var sky: SkyState
    /// Seconds, used only for gentle motion (clouds, snow, leaves, twinkling).
    var time: Double

    var body: some View {
        Canvas { context, size in
            SceneRenderer(sky: sky, time: time, size: size).draw(&context)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Fixed scenery (same every launch)

struct SeededRandom {
    var state: UInt64
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(UInt64(1) << 53)
    }
}

private struct TreeSpot { var u: Double; var scale: Double; var isPine: Bool; var tone: Int }
private struct Speck { var x: Double; var y: Double; var size: Double; var phase: Double; var tone: Int }

private enum Scenery {
    static func specks(_ n: Int, seed: UInt64) -> [Speck] {
        var r = SeededRandom(state: seed)
        return (0..<n).map { _ in
            Speck(x: r.next(), y: r.next(), size: r.next(), phase: r.next() * 6.283, tone: Int(r.next() * 100))
        }
    }
    static let stars = specks(170, seed: 11)
    static let flowers = specks(80, seed: 23)
    static let snow = specks(110, seed: 31)
    static let leaves = specks(16, seed: 41)
    static let petals = specks(22, seed: 53)
    static let fireflies = specks(26, seed: 67)
    static let blossoms = specks(14, seed: 79)

    static let hillTrees: [TreeSpot] = {
        var r = SeededRandom(state: 97)
        var trees: [TreeSpot] = []
        var u = 0.0
        while u < 1.02 {
            trees.append(TreeSpot(u: u, scale: 0.6 + r.next() * 0.6, isPine: r.next() < 0.45, tone: Int(r.next() * 100)))
            u += 0.025 + r.next() * 0.06
        }
        return trees
    }()

    // (x offset, y offset, radius) in units of tree height, for a round crown
    static let crown: [(Double, Double, Double)] = [
        (0, -0.66, 0.27), (-0.19, -0.57, 0.2), (0.2, -0.59, 0.21), (-0.07, -0.85, 0.2), (0.1, -0.82, 0.19),
    ]
}

// MARK: - Renderer

private struct SceneRenderer {
    let sky: SkyState
    let time: Double
    let size: CGSize

    var W: Double { Double(size.width) }
    var H: Double { Double(size.height) }
    var horizon: Double { H * 0.64 }
    var skyHeight: Double { horizon * 0.95 }
    var unit: Double { min(W, H) }

    func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

    // Seasons
    var winter: Double { sky.weight(.winter) }
    var spring: Double { sky.weight(.spring) }
    var summer: Double { sky.weight(.summer) }
    var autumn: Double { sky.weight(.autumn) }

    /// Applies time-of-day light to a landscape colour: blue moonlit night, warm golden hour.
    func lit(_ c: RGB) -> RGB {
        let moonLight = sky.moonAltitude > 0 ? sky.moonFraction * 0.5 : 0
        let night = RGB(c.r * 0.17 + 0.02, c.g * 0.21 + 0.03, c.b * 0.33 + 0.08) * (1 + moonLight)
        let warm = c.mixed(with: RGB(c.r * 1.12 + 0.08, c.g * 0.92 + 0.03, c.b * 0.72), sky.goldenHour * 0.6)
        return night.mixed(with: warm, sky.daylight)
    }

    func skyPoint(altitude: Double, x: Double) -> CGPoint {
        pt(x * W, horizon - sin(altitude * .pi / 180) * skyHeight)
    }

    // MARK: Draw

    func draw(_ ctx: inout GraphicsContext) {
        let colors = Palette.sky(altitude: sky.sunAltitude)
        drawSky(&ctx, colors)
        drawStars(&ctx)
        drawSunGlow(&ctx)
        drawMoon(&ctx)
        drawSun(&ctx)
        drawClouds(&ctx)
        drawMountains(&ctx, horizonColor: colors.horizon)
        drawHills(&ctx)
        drawMeadow(&ctx)
        drawForegroundTrees(&ctx)
        drawWeatherAndLife(&ctx)
    }

    // MARK: Sky

    func drawSky(_ ctx: inout GraphicsContext, _ c: (top: RGB, horizon: RGB)) {
        let pale = winter * 0.15 * sky.daylight
        let top = c.top.mixed(with: RGB(0.8, 0.85, 0.9), pale)
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [top.color, c.horizon.color]),
                                       startPoint: .zero, endPoint: pt(0, horizon)))
    }

    func drawStars(_ ctx: inout GraphicsContext) {
        guard sky.starVisibility > 0.01 else { return }
        for s in Scenery.stars {
            let twinkle = 0.55 + 0.45 * sin(time * 1.3 + s.phase * 3)
            let r = 0.5 + s.size * 1.4
            let p = pt(s.x * W, s.y * horizon * 0.95)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
                     with: .color(.white.opacity(sky.starVisibility * twinkle * (0.4 + 0.6 * s.y.squareRoot()))))
        }
    }

    func drawSunGlow(_ ctx: inout GraphicsContext) {
        let p = skyPoint(altitude: max(sky.sunAltitude, -6), x: sky.sunX)
        let strength = sky.goldenHour * 0.75 + sky.daylight * 0.25
        guard strength > 0.01 else { return }
        let warm = RGB(hex: 0xFFC27A).mixed(with: RGB(hex: 0xFFF4D6), sky.daylight * (1 - sky.goldenHour))
        let radius = max(W, H) * 0.7
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(Gradient(colors: [warm.color(strength * 0.6), warm.color(0)]),
                                       center: p, startRadius: 0, endRadius: radius))
    }

    func drawSun(_ ctx: inout GraphicsContext) {
        guard sky.sunAltitude > -3 else { return }
        let p = skyPoint(altitude: sky.sunAltitude, x: sky.sunX)
        let r = unit * 0.045
        let c = RGB(hex: 0xFFF6D8).mixed(with: RGB(hex: 0xFF9A4A), sky.goldenHour)
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 3, y: p.y - r * 3, width: r * 6, height: r * 6)),
                 with: .radialGradient(Gradient(colors: [c.color(0.55), c.color(0)]),
                                       center: p, startRadius: r * 0.8, endRadius: r * 3))
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(c.color))
    }

    func drawMoon(_ ctx: inout GraphicsContext) {
        guard sky.moonAltitude > -4 else { return }
        let c = skyPoint(altitude: sky.moonAltitude, x: sky.moonX)
        let r = unit * 0.034
        let night = 1 - sky.daylight
        let moonColor = RGB(hex: 0xF5EDD3)

        // halo
        let halo = (0.15 + 0.45 * sky.moonFraction) * night
        if halo > 0.01 {
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 5, y: c.y - r * 5, width: r * 10, height: r * 10)),
                     with: .radialGradient(Gradient(colors: [moonColor.color(halo * 0.5), moonColor.color(0)]),
                                           center: c, startRadius: r, endRadius: r * 5))
        }
        // dark disc (earthshine) at night
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                 with: .color(RGB(hex: 0x2A3150).color(0.55 * night)))
        // lit part — paler during the day, like the real daytime moon
        let litPath = moonLitPath(center: c, r: r, phase: sky.moonPhase, flip: sky.latitude < 0)
        ctx.fill(litPath, with: .color(moonColor.color(0.55 + 0.45 * night)))
    }

    func moonLitPath(center c: CGPoint, r: Double, phase: Double, flip: Bool) -> Path {
        let waxing = phase < 0.5
        let p = waxing ? phase : 1 - phase           // 0 (new) … 0.5 (full)
        let e = cos(2 * .pi * p)                     // 1 … −1
        var side: Double = waxing ? 1 : -1           // northern view: waxing lit on the right
        if flip { side = -side }
        var path = Path()
        let steps = 36
        for i in 0...steps {                         // outer edge, top → bottom
            let a = -Double.pi / 2 + .pi * Double(i) / Double(steps)
            let q = pt(c.x + side * r * cos(a), c.y + r * sin(a))
            if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
        }
        for i in 0...steps {                         // terminator, bottom → top
            let a = Double.pi / 2 - .pi * Double(i) / Double(steps)
            path.addLine(to: pt(c.x + side * r * e * cos(a), c.y + r * sin(a)))
        }
        path.closeSubpath()
        return path
    }

    func drawClouds(_ ctx: inout GraphicsContext) {
        let day = RGB(1, 1, 1).mixed(with: RGB(hex: 0xFFC6A8), sky.goldenHour * 0.8)
        let night = RGB(hex: 0x3A4268)
        let c = night.mixed(with: day, sky.daylight)
        let alpha = 0.35 + 0.5 * sky.daylight
        let clouds: [(Double, Double, Double, Double)] = [   // (start, height, size, speed)
            (0.05, 0.18, 1.0, 4), (0.42, 0.10, 0.7, 6), (0.7, 0.30, 1.2, 3), (0.25, 0.42, 0.8, 5),
        ]
        for (start, h, s, speed) in clouds {
            let cw = unit * 0.22 * s
            let span = W + cw * 2
            var x = (start * span + time * speed).truncatingRemainder(dividingBy: span) - cw
            if x < -cw { x += span }
            let y = horizon * h + unit * 0.04
            var path = Path()
            for (dx, dy, dr) in [(-0.35, 0.05, 0.28), (-0.08, -0.1, 0.36), (0.25, -0.02, 0.3), (0.5, 0.08, 0.2)] {
                let rr = cw * dr
                path.addEllipse(in: CGRect(x: x + cw * dx - rr, y: y + cw * dy - rr, width: rr * 2, height: rr * 2))
            }
            path.addRoundedRect(in: CGRect(x: x - cw * 0.5, y: y, width: cw * 1.1, height: cw * 0.22),
                                cornerSize: CGSize(width: cw * 0.11, height: cw * 0.11))
            ctx.fill(path, with: .color(c.color(alpha)))
        }
    }

    // MARK: Land

    func ridgePath(_ top: (Double) -> Double, step: Double = 4) -> Path {
        var path = Path()
        path.move(to: pt(0, H))
        var x = 0.0
        while x <= W + step {
            path.addLine(to: pt(x, top(x / W)))
            x += step
        }
        path.addLine(to: pt(W, H))
        path.closeSubpath()
        return path
    }

    func drawMountains(_ ctx: inout GraphicsContext, horizonColor: RGB) {
        // far range
        let far: (Double) -> Double = { u in
            self.horizon - self.H * (0.10 + 0.06 * sin(u * 6.3 + 1.1) + 0.04 * sin(u * 13.7 + 0.4) + 0.022 * sin(u * 29 + 2))
        }
        let farPath = ridgePath(far)
        ctx.fill(farPath, with: .color(lit(Palette.farMountain).mixed(with: horizonColor, 0.35).color))

        let snowAmount = min(max(0.3 + 0.7 * winter + 0.35 * spring + 0.1 * autumn - 0.15 * summer, 0), 1)
        drawSnowCap(&ctx, ridge: farPath, line: { u in self.horizon - self.H * (0.155 + 0.01 * sin(u * 70)) },
                    opacity: snowAmount, horizonColor: horizonColor, haze: 0.3)

        // nearer range
        let near: (Double) -> Double = { u in
            self.horizon - self.H * (0.05 + 0.04 * sin(u * 5 + 3) + 0.02 * sin(u * 17 + 1) + 0.008 * sin(u * 41))
        }
        let nearPath = ridgePath(near)
        ctx.fill(nearPath, with: .color(lit(RGB(hex: 0x4D6A80)).mixed(with: horizonColor, 0.18).color))
        drawSnowCap(&ctx, ridge: nearPath, line: { u in self.horizon - self.H * (0.07 + 0.008 * sin(u * 60)) },
                    opacity: winter * 0.95, horizonColor: horizonColor, haze: 0.15)
    }

    func drawSnowCap(_ ctx: inout GraphicsContext, ridge: Path, line: @escaping (Double) -> Double,
                     opacity: Double, horizonColor: RGB, haze: Double) {
        guard opacity > 0.01 else { return }
        var clip = Path()
        clip.move(to: .zero)
        var x = 0.0
        while x <= W + 4 { clip.addLine(to: pt(x, line(x / W))); x += 4 }
        clip.addLine(to: pt(W, 0))
        clip.closeSubpath()
        let snow = lit(Palette.snow).mixed(with: horizonColor, haze)
        ctx.drawLayer { layer in
            layer.clip(to: clip)
            layer.fill(ridge, with: .color(snow.color(opacity)))
        }
    }

    func hillTop(_ u: Double) -> Double {
        horizon + H * 0.035 - H * (0.03 + 0.028 * sin(u * 4.1 + 2) + 0.012 * sin(u * 11 + 1))
    }

    func meadowTop(_ u: Double) -> Double {
        H * 0.80 + H * 0.018 * sin(u * 5 + 0.5) + H * 0.01 * sin(u * 13)
    }

    func drawHills(_ ctx: inout GraphicsContext) {
        ctx.fill(ridgePath(hillTop), with: .color(lit(Palette.hills(sky)).color))
        for t in Scenery.hillTrees {
            let base = pt(t.u * W, hillTop(t.u) + H * 0.008)
            let h = H * 0.065 * t.scale
            if t.isPine { drawPine(&ctx, base: base, h: h, tone: t.tone) }
            else { drawLeafTree(&ctx, base: base, h: h, tone: t.tone, detail: false) }
        }
    }

    func drawMeadow(_ ctx: inout GraphicsContext) {
        let top = lit(Palette.meadow(sky)), bottom = lit(Palette.meadowFront(sky))
        ctx.fill(ridgePath(meadowTop),
                 with: .linearGradient(Gradient(colors: [top.color, bottom.color]),
                                       startPoint: pt(0, H * 0.78), endPoint: pt(0, H)))

        // flowers in spring & summer
        let bloom = spring + summer * 0.6
        if bloom > 0.02 {
            for f in Scenery.flowers {
                let x = f.x * W
                let y = meadowTop(f.x) + H * 0.015 + f.y * (H - meadowTop(f.x)) * 0.9
                let r = (1.5 + f.size * 2.5) * (0.6 + 0.6 * (y / H))
                let c = lit(Palette.flowers[f.tone % Palette.flowers.count])
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(c.color(bloom)))
            }
        }
        // fallen leaves in autumn
        if autumn > 0.02 {
            for f in Scenery.flowers {
                let x = (f.x + 0.37).truncatingRemainder(dividingBy: 1) * W
                let y = meadowTop(f.x) + H * 0.02 + f.y * (H - meadowTop(f.x)) * 0.9
                let c = lit(Palette.autumnLeaves[f.tone % 4])
                var leaf = ctx
                leaf.translateBy(x: x, y: y)
                leaf.rotate(by: .radians(f.phase))
                let s = 3 + f.size * 4
                leaf.fill(Path(ellipseIn: CGRect(x: -s, y: -s * 0.45, width: s * 2, height: s * 0.9)), with: .color(c.color(autumn)))
            }
        }
    }

    func drawForegroundTrees(_ ctx: inout GraphicsContext) {
        let h = H * 0.34
        drawLeafTree(&ctx, base: pt(W * 0.09, meadowTop(0.09) + H * 0.03), h: h, tone: 1, detail: true)
        drawPine(&ctx, base: pt(W * 0.93, meadowTop(0.93) + H * 0.03), h: h * 0.95, tone: 3)
        drawPine(&ctx, base: pt(W * 0.84, meadowTop(0.84) + H * 0.02), h: h * 0.62, tone: 7)
    }

    // MARK: Trees

    func drawPine(_ ctx: inout GraphicsContext, base: CGPoint, h: Double, tone: Int) {
        let trunkW = h * 0.07
        ctx.fill(Path(CGRect(x: base.x - trunkW / 2, y: base.y - h * 0.16, width: trunkW, height: h * 0.16)),
                 with: .color(lit(Palette.trunk).color))
        let green = lit(Palette.pine.mixed(with: RGB(hex: 0x3F6E4E), Double(tone % 5) / 6))
        for i in 0..<3 {
            let d = Double(i)
            let bottom = base.y - h * (0.12 + d * 0.24)
            let top = bottom - h * 0.42
            let half = h * (0.31 - d * 0.075)
            var tri = Path()
            tri.move(to: pt(base.x - half, bottom))
            tri.addLine(to: pt(base.x, top))
            tri.addLine(to: pt(base.x + half, bottom))
            tri.closeSubpath()
            ctx.fill(tri, with: .color(green.color))
            if winter > 0.02 {
                var cap = Path()
                let capBottom = top + (bottom - top) * 0.5
                let capHalf = half * 0.5
                cap.move(to: pt(base.x - capHalf, capBottom))
                cap.addQuadCurve(to: pt(base.x + capHalf, capBottom), control: pt(base.x, capBottom - h * 0.03))
                cap.addLine(to: pt(base.x, top))
                cap.closeSubpath()
                ctx.fill(cap, with: .color(lit(Palette.snow).color(winter)))
            }
        }
    }

    func drawLeafTree(_ ctx: inout GraphicsContext, base: CGPoint, h: Double, tone: Int, detail: Bool) {
        let trunk = lit(Palette.trunk)
        // trunk
        var t = Path()
        t.move(to: pt(base.x - h * 0.045, base.y))
        t.addLine(to: pt(base.x - h * 0.022, base.y - h * 0.62))
        t.addLine(to: pt(base.x + h * 0.022, base.y - h * 0.62))
        t.addLine(to: pt(base.x + h * 0.045, base.y))
        t.closeSubpath()
        ctx.fill(t, with: .color(trunk.color))
        // branches (visible when leaves are gone)
        var b = Path()
        for (sx, ex, ey) in [(-0.3, -0.24, -0.82), (-0.45, -0.05, -0.95), (-0.35, 0.22, -0.84), (-0.5, 0.12, -0.7), (-0.25, -0.2, -0.62)] {
            let start = pt(base.x, base.y + h * sx)
            b.move(to: start)
            b.addQuadCurve(to: pt(base.x + h * ex, base.y + h * ey), control: pt(base.x + h * ex * 0.3, base.y + h * (sx + ey) / 2))
        }
        ctx.stroke(b, with: .color(trunk.color), style: StrokeStyle(lineWidth: max(1, h * 0.022), lineCap: .round))

        // crown
        let leafAmount = 1 - winter
        guard leafAmount > 0.02 else { return }
        let autumnC = Palette.autumnLeaves[tone % 4]
        let raw = RGB(hex: 0x9BCB63) * spring + RGB(hex: 0x4B8B3B) * summer + autumnC * autumn
        let leaf = lit(raw * (1 / max(leafAmount, 0.001)))
        let light = leaf.mixed(with: RGB(1, 1, 0.85), 0.18 * sky.daylight)
        let grow = 0.75 + 0.25 * leafAmount
        for (dx, dy, dr) in Scenery.crown {
            let r = h * dr * grow
            let c = pt(base.x + h * dx, base.y + h * dy)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(leaf.color(leafAmount)))
        }
        if detail {
            for (dx, dy, dr) in Scenery.crown.prefix(3) {
                let r = h * dr * grow * 0.55
                let c = pt(base.x + h * (dx - 0.05), base.y + h * (dy - 0.06))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(light.color(leafAmount * 0.8)))
            }
        }
        // spring blossoms
        if spring > 0.05 {
            let pink = lit(RGB(hex: 0xF7B9CF))
            for s in Scenery.blossoms {
                let r = h * (0.018 + s.size * 0.02)
                let c = pt(base.x + h * (s.x - 0.5) * 0.6, base.y - h * (0.5 + s.y * 0.45))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(pink.color(spring)))
            }
        }
    }

    // MARK: Snow, leaves, petals, fireflies, birds

    func drawWeatherAndLife(_ ctx: inout GraphicsContext) {
        if winter > 0.05 {
            for s in Scenery.snow {
                let speed = 0.04 + s.size * 0.05
                let y = (s.y * H + time * H * speed).truncatingRemainder(dividingBy: H)
                var x = s.x * W + sin(time * 0.6 + s.phase) * 18 + time * 6
                x = x.truncatingRemainder(dividingBy: W)
                let r = 1 + s.size * 2.2
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                         with: .color(.white.opacity(winter * (0.5 + 0.4 * s.size) * (0.5 + 0.5 * sky.daylight + 0.2))))
            }
        }
        if autumn > 0.05 {
            for l in Scenery.leaves {
                let span = H + 40
                let y = (l.y * span + time * H * (0.03 + l.size * 0.03)).truncatingRemainder(dividingBy: span) - 20
                let x = l.x * W + sin(time * 0.9 + l.phase) * 35
                var g = ctx
                g.translateBy(x: x, y: y)
                g.rotate(by: .radians(time * 1.5 + l.phase))
                let s = 4 + l.size * 4
                g.fill(Path(ellipseIn: CGRect(x: -s, y: -s * 0.45, width: s * 2, height: s * 0.9)),
                       with: .color(lit(Palette.autumnLeaves[l.tone % 4]).color(autumn)))
            }
        }
        if spring > 0.05 {
            for p in Scenery.petals {
                let span = H + 30
                let y = (p.y * span + time * H * 0.025).truncatingRemainder(dividingBy: span) - 15
                let x = p.x * W + sin(time * 1.1 + p.phase) * 25
                var g = ctx
                g.translateBy(x: x, y: y)
                g.rotate(by: .radians(time + p.phase))
                g.fill(Path(ellipseIn: CGRect(x: -3, y: -1.6, width: 6, height: 3.2)),
                       with: .color(lit(RGB(hex: 0xF8C3D6)).color(spring * 0.85)))
            }
        }
        let fireflyAmount = (summer + spring * 0.3) * (1 - sky.daylight)
        if fireflyAmount > 0.02 {
            for f in Scenery.fireflies {
                let x = f.x * W + sin(time * 0.4 + f.phase) * 30
                let y = H * 0.70 + f.y * H * 0.26 + cos(time * 0.55 + f.phase) * 14
                let pulse = max(0, sin(time * 1.7 + f.phase * 2))
                let r = 7.0
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                         with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.95, blue: 0.55).opacity(fireflyAmount * pulse),
                                                                 Color(red: 1, green: 0.9, blue: 0.4).opacity(0)]),
                                               center: pt(x, y), startRadius: 0, endRadius: r))
            }
        }
        let birds = sky.daylight * (1 - winter)
        if birds > 0.2 {
            let ink = RGB(hex: 0x2B2F3A).color(0.55 * birds)
            for i in 0..<3 {
                let span = W + 200
                let x = (time * 22 + Double(i) * 70).truncatingRemainder(dividingBy: span) - 100
                let y = horizon * 0.32 + Double(i) * 16 + sin(time * 0.8 + Double(i)) * 6
                let flap = sin(time * 6 + Double(i)) * 3
                var b = Path()
                b.move(to: pt(x - 7, y - 2 + flap))
                b.addQuadCurve(to: pt(x, y), control: pt(x - 3, y - 4 + flap))
                b.addQuadCurve(to: pt(x + 7, y - 2 + flap), control: pt(x + 3, y - 4 + flap))
                ctx.stroke(b, with: .color(ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        }
    }
}
