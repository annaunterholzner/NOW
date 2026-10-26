import SwiftUI

/// A tiny RGB colour type that is easy to blend.
struct RGB {
    var r: Double, g: Double, b: Double

    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }

    init(hex: UInt32) {
        r = Double((hex >> 16) & 0xff) / 255
        g = Double((hex >> 8) & 0xff) / 255
        b = Double(hex & 0xff) / 255
    }

    func mixed(with o: RGB, _ t: Double) -> RGB {
        RGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t)
    }

    static func + (a: RGB, b: RGB) -> RGB { RGB(a.r + b.r, a.g + b.g, a.b + b.b) }
    static func * (a: RGB, k: Double) -> RGB { RGB(a.r * k, a.g * k, a.b * k) }

    var color: Color { Color(red: r, green: g, blue: b) }
    func color(_ opacity: Double) -> Color { Color(red: r, green: g, blue: b).opacity(opacity) }
}

/// The illustrated colour world, per season.
enum Palette {
    // Sky keyframes by sun altitude (degrees): (altitude, top, horizon)
    static let skyKeys: [(Double, RGB, RGB)] = [
        (-18, RGB(hex: 0x0A0F24), RGB(hex: 0x18213F)),
        (-9,  RGB(hex: 0x161C47), RGB(hex: 0x3E3A6E)),
        (-3,  RGB(hex: 0x2B3772), RGB(hex: 0xE07B66)),
        (1,   RGB(hex: 0x4A6AAE), RGB(hex: 0xF7A65E)),
        (6,   RGB(hex: 0x6C9BD2), RGB(hex: 0xFFD596)),
        (14,  RGB(hex: 0x6FA9DE), RGB(hex: 0xCDE7F3)),
        (45,  RGB(hex: 0x4B90D6), RGB(hex: 0xBEE0F4)),
    ]

    static func sky(altitude: Double) -> (top: RGB, horizon: RGB) {
        let keys = skyKeys
        if altitude <= keys.first!.0 { return (keys.first!.1, keys.first!.2) }
        if altitude >= keys.last!.0 { return (keys.last!.1, keys.last!.2) }
        for i in 0..<(keys.count - 1) where altitude >= keys[i].0 && altitude <= keys[i + 1].0 {
            let t = (altitude - keys[i].0) / (keys[i + 1].0 - keys[i].0)
            return (keys[i].1.mixed(with: keys[i + 1].1, t), keys[i].2.mixed(with: keys[i + 1].2, t))
        }
        return (keys.last!.1, keys.last!.2)
    }

    static func seasonal(_ sky: SkyState, winter: RGB, spring: RGB, summer: RGB, autumn: RGB) -> RGB {
        winter * sky.weight(.winter) + spring * sky.weight(.spring)
            + summer * sky.weight(.summer) + autumn * sky.weight(.autumn)
    }

    // Ground & plants
    static let farMountain = RGB(hex: 0x6E7FA6)
    static let snow = RGB(hex: 0xF2F6FA)

    static func hills(_ s: SkyState) -> RGB {
        seasonal(s, winter: RGB(hex: 0xDCE5EE), spring: RGB(hex: 0x8DC26F),
                 summer: RGB(hex: 0x5E9B4C), autumn: RGB(hex: 0xB89146))
    }
    static func meadow(_ s: SkyState) -> RGB {
        seasonal(s, winter: RGB(hex: 0xEAF0F5), spring: RGB(hex: 0x76B65C),
                 summer: RGB(hex: 0x4F8E3F), autumn: RGB(hex: 0xA97C3A))
    }
    static func meadowFront(_ s: SkyState) -> RGB {
        seasonal(s, winter: RGB(hex: 0xF4F7FA), spring: RGB(hex: 0x5FA04A),
                 summer: RGB(hex: 0x3F7A34), autumn: RGB(hex: 0x8E6430))
    }
    static let pine = RGB(hex: 0x2E5B45)
    static let trunk = RGB(hex: 0x5B4033)

    static let autumnLeaves = [RGB(hex: 0xE0892E), RGB(hex: 0xC9512E), RGB(hex: 0xE8B53E), RGB(hex: 0xB5402A)]
    static let flowers = [RGB(hex: 0xF6D04D), RGB(hex: 0xF29BB8), RGB(hex: 0xFFFFFF), RGB(hex: 0xB79CEB), RGB(hex: 0xF47C5E)]
}
