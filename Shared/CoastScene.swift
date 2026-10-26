import SwiftUI

/// The Coast scenery: sea with a light path from the sun or moon, a beach with washing waves,
/// dunes with grass, a far island and a headland with a lighthouse that shines at night.
/// Near the equator a palm grows on the dune; elsewhere a pine.
extension SceneRenderer {

    func drawCoast(_ ctx: inout GraphicsContext, horizonColor hor: RGB) {
        let tropical = abs(sky.latitude) < 23
        func seasonal(_ w: UInt32, _ sp: UInt32, _ su: UInt32, _ au: UInt32) -> RGB {
            Palette.seasonal(sky, winter: RGB(hex: w), spring: RGB(hex: sp), summer: RGB(hex: su), autumn: RGB(hex: au))
        }

        // Far island and headland
        let island: (Double) -> Double = { u in
            let d = (u - 0.16) / 0.1
            return d * d < 1 ? self.horizon - self.H * 0.022 * (1 - d * d) - self.H * 0.003 * sin(u * 90) : self.horizon + 2
        }
        ctx.fill(ridgePath(island), with: .color(lit(RGB(hex: 0x5E7A6E)).mixed(with: hor, 0.5).color))

        let head: (Double) -> Double = { u in
            self.horizon + 2 - self.H * smoothstep(0.6, 0.8, u) * (0.055 + 0.01 * sin(u * 31) + 0.006 * sin(u * 77))
        }
        let headPath = ridgePath(head)
        ctx.fill(headPath, with: .color(lit(seasonal(0x7D8C86, 0x5C7F5F, 0x557A55, 0x7A7552)).mixed(with: hor, 0.28).color))
        if winter > 0.02 {
            ctx.fill(headPath, with: .color(lit(Palette.snow).mixed(with: hor, 0.25).color(winter * 0.55)))
        }
        drawLighthouse(&ctx, x: W * 0.84, y: head(0.84) + 1, h: H * 0.075, hor: hor)

        // Sea
        let shoreBase = H * 0.79
        let shoreY: (Double) -> Double = { u in shoreBase + self.H * 0.012 * sin(u * 4 + 1) }
        let seaFar = lit(seasonal(0x48667C, 0x3A7C9C, 0x2C84A6, 0x3B6A85))
        let seaNear = lit(seasonal(0x6C95A2, 0x4CA7B3, 0x3DBDBE, 0x5893A0))
        ctx.fill(Path(CGRect(x: 0, y: horizon, width: W, height: H - horizon)),
                 with: .linearGradient(Gradient(stops: [
                    .init(color: hor.mixed(with: seaFar, 0.55).color, location: 0),
                    .init(color: seaFar.color, location: 0.25),
                    .init(color: seaNear.color, location: 1),
                 ]), startPoint: pt(0, horizon), endPoint: pt(0, H * 0.82)))
        ctx.fill(Path(CGRect(x: 0, y: horizon - 0.5, width: W, height: 1)),
                 with: .color(hor.mixed(with: RGB(1, 1, 1), 0.3).color(0.5)))

        // Wave lines drifting towards the beach
        for k in 0..<15 {
            let t = (Double(k) / 15 + time * 0.01).truncatingRemainder(dividingBy: 1)
            let y = horizon + (shoreBase - horizon) * t * t
            var p = Path()
            for j in 0..<8 {
                let sp = Scenery.waves[k * 8 + j]
                let len = (8 + sp.size * 34) * (0.3 + t) * unit / 700
                var x = (sp.x * W + time * (k % 2 == 1 ? 3 : -3)).truncatingRemainder(dividingBy: W)
                if x < 0 { x += W }
                p.move(to: pt(x, y))
                p.addLine(to: pt(x + len, y))
            }
            ctx.stroke(p, with: .color(.white.opacity(0.22 * sin(.pi * t) * (0.4 + 0.6 * sky.daylight))),
                       style: StrokeStyle(lineWidth: 0.8 + t * 1.6, lineCap: .round))
        }

        // Light path on the water
        drawGlitter(&ctx, x: sky.sunX * W, color: sunColor.mixed(with: RGB(1, 1, 1), 0.2),
                    intensity: (0.35 + 0.6 * sky.goldenHour) * smoothstep(-1, 3, sky.sunAltitude), shore: H * 0.785)
        drawGlitter(&ctx, x: sky.moonX * W, color: RGB(hex: 0xF5EDD3),
                    intensity: (1 - sky.daylight) * sky.moonFraction * 0.9 * smoothstep(-1, 3, sky.moonAltitude), shore: H * 0.785)

        // Beach: wet sand, the washing wave, dry sand
        let sand = lit(seasonal(0xD3CEC4, 0xEAD7A9, 0xF0D9A2, 0xDDC596))
        ctx.fill(ridgePath(shoreY), with: .color(sand.mixed(with: RGB(0.35, 0.3, 0.25), 0.28).color))

        let wave = 0.5 + 0.5 * sin(time * 0.6)
        let washY: (Double) -> Double = { u in
            shoreY(u) + self.H * (0.003 + 0.016 * wave) + self.H * 0.003 * sin(u * 23 + self.time * 0.8)
        }
        var wash = Path()
        wash.move(to: pt(0, shoreY(0)))
        var x = 0.0
        while x <= W + 4 { wash.addLine(to: pt(x, shoreY(x / W))); x += 4 }
        x = W + 4
        while x >= 0 { wash.addLine(to: pt(x, washY(x / W))); x -= 4 }
        wash.closeSubpath()
        ctx.fill(wash, with: .color(seaNear.color(0.55)))

        var foam = Path()
        foam.move(to: pt(0, washY(0)))
        x = 0
        while x <= W + 4 { foam.addLine(to: pt(x, washY(x / W))); x += 4 }
        ctx.stroke(foam, with: .color(.white.opacity(0.45 + 0.4 * sky.daylight)), lineWidth: 2)

        let dryY: (Double) -> Double = { u in shoreY(u) + self.H * 0.035 + self.H * 0.006 * sin(u * 7) }
        let dryPath = ridgePath(dryY)
        ctx.fill(dryPath, with: .linearGradient(
            Gradient(colors: [sand.color, sand.mixed(with: RGB(0.4, 0.3, 0.2), 0.12).color]),
            startPoint: pt(0, H * 0.8), endPoint: pt(0, H)))
        if winter > 0.02 { ctx.fill(dryPath, with: .color(lit(Palette.snow).color(winter * 0.7))) }

        for sh in Scenery.shells {
            let y = dryY(sh.x) + (H - dryY(sh.x)) * (0.1 + sh.y * 0.7)
            var g = ctx
            g.translateBy(x: sh.x * W, y: y)
            g.rotate(by: .radians(sh.phase))
            let w = 2 + sh.size * 2.5, h = 1.4 + sh.size * 1.5
            let c = lit(RGB(hex: sh.tone % 2 == 1 ? 0xF7EBDD : 0xE9C4B4))
            g.fill(Path(ellipseIn: CGRect(x: -w, y: -h, width: 2 * w, height: 2 * h)), with: .color(c.color(0.9 * (1 - winter * 0.8))))
        }

        // Dunes with grass
        let duneL: (Double) -> Double = { u in u < 0.38 ? self.H * 0.99 - self.H * 0.16 * (1 - pow(u / 0.38, 2)) : self.H + 20 }
        let duneR: (Double) -> Double = { u in u > 0.74 ? self.H * 1.0 - self.H * 0.11 * (1 - pow((1 - u) / 0.26, 2)) : self.H + 20 }
        let duneColor = lit(seasonal(0xBDB5A6, 0xD2B178, 0xD8B476, 0xC4A470))
        for dune in [duneL, duneR] {
            let path = ridgePath(dune)
            ctx.fill(path, with: .color(duneColor.color))
            if winter > 0.02 { ctx.fill(path, with: .color(lit(Palette.snow).color(winter * 0.75))) }
        }

        let grassColor = lit(seasonal(0xA79C80, 0x8DB860, 0x7FA650, 0xC2A15A))
        var grass = Path()
        for gr in Scenery.grass {
            let left = gr.tone < 55
            let u = left ? gr.x * 0.34 : 0.77 + gr.x * 0.23
            let bx = u * W
            let by = (left ? duneL(u) : duneR(u)) + H * 0.006 + gr.y * H * 0.035
            let len = H * (0.028 + gr.size * 0.03)
            let sway = sin(time * 1.1 + gr.phase) * 0.12 + 0.15
            for b in 0..<5 {
                let a = -Double.pi / 2 + Double(b - 2) * 0.24 + sway
                grass.move(to: pt(bx, by))
                grass.addQuadCurve(to: pt(bx + cos(a + sway * 0.6) * len, by + sin(a) * len),
                                   control: pt(bx + cos(a) * len * 0.4, by + sin(a) * len * 0.6))
            }
        }
        ctx.stroke(grass, with: .color(grassColor.color), style: StrokeStyle(lineWidth: max(1, H * 0.0025), lineCap: .round))

        if tropical {
            drawPalm(&ctx, base: pt(W * 0.13, duneL(0.13) + H * 0.01), h: H * 0.42)
        } else {
            drawPine(&ctx, base: pt(W * 0.11, duneL(0.11) + H * 0.02), h: H * 0.3, tone: 3)
        }
    }

    func drawGlitter(_ ctx: inout GraphicsContext, x bx: Double, color: RGB, intensity: Double, shore: Double) {
        guard intensity > 0.02 else { return }
        for i in 0..<44 {
            let f = (Double(i) + 0.5) / 44
            let y = horizon + (shore - horizon) * f * f
            let w = (5 + f * 80) * unit / 700
            let x = bx + sin(time * 1.3 + Double(i) * 2.1) * w * 0.7
            let flicker = pow(sin(time * 2.2 + Double(i) * 1.9), 2)
            var p = Path()
            p.move(to: pt(x - w / 2, y))
            p.addLine(to: pt(x + w / 2, y))
            ctx.stroke(p, with: .color(color.color(intensity * (0.2 + 0.8 * flicker))), lineWidth: 1 + f * 2.4)
        }
    }

    func drawLighthouse(_ ctx: inout GraphicsContext, x: Double, y: Double, h: Double, hor: RGB) {
        let bw = h * 0.24, tw = h * 0.16
        let night = 1 - sky.daylight
        func width(_ f: Double) -> Double { bw + (tw - bw) * f }
        func band(_ f0: Double, _ f1: Double, _ c: RGB) {
            var p = Path()
            p.move(to: pt(x - width(f0) / 2, y - h * f0))
            p.addLine(to: pt(x - width(f1) / 2, y - h * f1))
            p.addLine(to: pt(x + width(f1) / 2, y - h * f1))
            p.addLine(to: pt(x + width(f0) / 2, y - h * f0))
            p.closeSubpath()
            ctx.fill(p, with: .color(c.color))
        }
        let white = lit(RGB(hex: 0xF4EFE6)).mixed(with: hor, 0.2)
        let red = lit(RGB(hex: 0xC8463A)).mixed(with: hor, 0.2)
        band(0, 1, white)
        band(0.22, 0.38, red)
        band(0.58, 0.74, red)
        ctx.fill(Path(CGRect(x: x - tw * 0.75, y: y - h * 1.02, width: tw * 1.5, height: h * 0.04)),
                 with: .color(lit(RGB(hex: 0x2B2F3A)).mixed(with: hor, 0.2).color))
        ctx.fill(Path(CGRect(x: x - tw * 0.4, y: y - h * 1.15, width: tw * 0.8, height: h * 0.13)),
                 with: .color(lit(RGB(hex: 0x39404F)).mixed(with: RGB(1, 0.88, 0.5), night).color))
        var roof = Path()
        roof.move(to: pt(x - tw * 0.55, y - h * 1.15))
        roof.addLine(to: pt(x, y - h * 1.27))
        roof.addLine(to: pt(x + tw * 0.55, y - h * 1.15))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(red.color))

        guard night > 0.05 else { return }
        let ly = y - h * 1.09
        let c = cos(time * 0.8)
        let len = W * 0.45 * abs(c)
        let dir: Double = c >= 0 ? 1 : -1
        let spread = h * 0.32
        let beamColor = Color(red: 1, green: 0.94, blue: 0.7)
        var beam = Path()
        beam.move(to: pt(x, ly - 1))
        beam.addLine(to: pt(x + dir * len, ly - spread))
        beam.addLine(to: pt(x + dir * len, ly + spread))
        beam.addLine(to: pt(x, ly + 1))
        beam.closeSubpath()
        ctx.fill(beam, with: .linearGradient(
            Gradient(colors: [beamColor.opacity(0.38 * night * (0.35 + 0.65 * abs(c))), beamColor.opacity(0)]),
            startPoint: pt(x, ly), endPoint: pt(x + dir * max(len, 1), ly)))
        let r = h * 0.35
        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: ly - r, width: 2 * r, height: 2 * r)),
                 with: .radialGradient(Gradient(colors: [beamColor.opacity(0.8 * night), beamColor.opacity(0)]),
                                       center: pt(x, ly), startRadius: 0, endRadius: r))
    }

    func drawPalm(_ ctx: inout GraphicsContext, base: CGPoint, h: Double) {
        let bx = Double(base.x), by = Double(base.y)
        let tx = bx + h * 0.2, ty = by - h
        let cx = bx - h * 0.06, cy = by - h * 0.55
        func bez(_ t: Double, _ a: Double, _ b: Double, _ c: Double) -> Double {
            (1 - t) * (1 - t) * a + 2 * (1 - t) * t * b + t * t * c
        }
        // trunk in segments, slightly banded
        let trunk = lit(RGB(hex: 0x8A6A4A))
        for i in 0..<14 {
            let a = Double(i) / 14, b = Double(i + 1) / 14
            var seg = Path()
            seg.move(to: pt(bez(a, bx, cx, tx), bez(a, by, cy, ty)))
            seg.addLine(to: pt(bez(b, bx, cx, tx), bez(b, by, cy, ty)))
            let c = i % 2 == 1 ? trunk : trunk.mixed(with: RGB(0, 0, 0), 0.12)
            ctx.stroke(seg, with: .color(c.color), style: StrokeStyle(lineWidth: h * (0.055 - 0.025 * a), lineCap: .round))
        }
        // fronds: tapered leaf shapes along drooping curves
        let green = lit(RGB(hex: 0x3F8A4A)), light = lit(RGB(hex: 0x5FA85A))
        for k in 0..<9 {
            let a = -Double.pi * (0.03 + 0.94 * Double(k) / 8) + sin(time * 0.9 + Double(k)) * 0.04
            let L = h * (0.34 + 0.05 * sin(Double(k) * 2.3))
            let droop = 0.25 + 0.35 * abs(cos(a))
            let ex = tx + cos(a) * L, ey = ty + sin(a) * L * 0.35 + L * droop
            let qx = tx + cos(a) * L * 0.55, qy = ty + sin(a) * L * 0.7 - L * 0.08
            var left: [CGPoint] = [], right: [CGPoint] = []
            for i in 0...14 {
                let t = Double(i) / 14
                let px = bez(t, tx, qx, ex), py = bez(t, ty, qy, ey)
                let dx = 2 * (1 - t) * (qx - tx) + 2 * t * (ex - qx)
                let dy = 2 * (1 - t) * (qy - ty) + 2 * t * (ey - qy)
                let l = max(hypot(dx, dy), 0.0001)
                let ww = h * 0.045 * pow(sin(.pi * min(t * 1.1, 1)), 0.7)
                left.append(pt(px - dy / l * ww, py + dx / l * ww))
                right.append(pt(px + dy / l * ww, py - dx / l * ww))
            }
            var frond = Path()
            frond.move(to: pt(tx, ty))
            left.forEach { frond.addLine(to: $0) }
            right.reversed().forEach { frond.addLine(to: $0) }
            frond.closeSubpath()
            ctx.fill(frond, with: .color((k % 2 == 1 ? green : light).color))
        }
        for (dx, dy) in [(-0.03, 0.03), (0.02, 0.04), (0.0, 0.07)] {
            let r = h * 0.028
            ctx.fill(Path(ellipseIn: CGRect(x: tx + h * dx - r, y: ty + h * dy - r, width: 2 * r, height: 2 * r)),
                     with: .color(lit(RGB(hex: 0x6B4A2E)).color))
        }
    }
}
