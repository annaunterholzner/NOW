import Foundation

/// Everything the illustration needs to know about "now, here":
/// where the sun and moon are, how bright it is, and which season it is.
struct SkyState {
    enum Season: Int, CaseIterable { case winter, spring, summer, autumn }

    var date: Date
    var latitude: Double
    var longitude: Double

    /// Sun height in degrees (negative = below horizon).
    var sunAltitude: Double
    /// Horizontal screen position 0…1 (left…right) of the sun, looking towards the equator.
    var sunX: Double
    var moonAltitude: Double
    var moonX: Double
    var moonFraction: Double
    /// 0…1, waxing < 0.5 < waning.
    var moonPhase: Double

    /// 0 = deep night, 1 = full daylight.
    var daylight: Double
    /// 0…1 how strong the warm sunrise / sunset glow is.
    var goldenHour: Double
    /// 0…1 how visible the stars are.
    var starVisibility: Double

    /// Blend weights for each season (they add up to 1).
    var seasonWeights: [Season: Double]

    var dominantSeason: Season {
        seasonWeights.max { $0.value < $1.value }?.key ?? .summer
    }

    func weight(_ s: Season) -> Double { seasonWeights[s] ?? 0 }

    init(date: Date, latitude: Double, longitude: Double) {
        self.date = date
        self.latitude = latitude
        self.longitude = longitude

        let sun = Astronomy.sun(at: date, latitude: latitude, longitude: longitude)
        let moon = Astronomy.moon(at: date, latitude: latitude, longitude: longitude)
        let phase = Astronomy.moonPhase(at: date)

        sunAltitude = sun.altitude * 180 / .pi
        moonAltitude = moon.altitude * 180 / .pi
        sunX = Self.screenX(azimuth: sun.azimuth, latitude: latitude)
        moonX = Self.screenX(azimuth: moon.azimuth, latitude: latitude)
        moonFraction = phase.fraction
        moonPhase = phase.phase

        daylight = smoothstep(-10, 8, sunAltitude)
        goldenHour = max(0, 1 - abs(sunAltitude - 1.5) / 8)
        starVisibility = 1 - smoothstep(-14, -4, sunAltitude)

        seasonWeights = Self.seasons(date: date, latitude: latitude)
    }

    /// The scene faces south in the northern hemisphere and north in the southern one,
    /// so the sun always rises on one side and sets on the other, like looking out a window.
    private static func screenX(azimuth: Double, latitude: Double) -> Double {
        var a = azimuth                       // from south, + towards west
        if latitude < 0 {                     // face north instead
            a = azimuth - .pi
            if a < -.pi { a += 2 * .pi }
        }
        // east (−90°) → left, west (+90°) → right; ±~125° span the whole width
        return 0.5 + a / (1.4 * .pi)
    }

    private static func seasons(date: Date, latitude: Double) -> [Season: Double] {
        // Close to the equator there is no real winter: keep it lush.
        if abs(latitude) < 23 {
            return [.winter: 0, .spring: 0.25, .summer: 0.75, .autumn: 0]
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let dayOfYear = Double(cal.ordinality(of: .day, in: .year, for: date) ?? 1)
        var s = dayOfYear / 365.25
        if latitude < 0 { s += 0.5 }          // seasons are flipped south of the equator

        // 0 = mid-winter (mid Jan), 1 = mid-spring, 2 = mid-summer, 3 = mid-autumn
        var t = (s - 0.04) * 4
        t = t.truncatingRemainder(dividingBy: 4)
        if t < 0 { t += 4 }

        let from = Int(t) % 4
        let to = (from + 1) % 4
        let blend = smoothstep(0.35, 0.65, t - floor(t))

        var w: [Season: Double] = [.winter: 0, .spring: 0, .summer: 0, .autumn: 0]
        w[Season(rawValue: from)!, default: 0] += 1 - blend
        w[Season(rawValue: to)!, default: 0] += blend
        return w
    }
}

func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)
}

func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
