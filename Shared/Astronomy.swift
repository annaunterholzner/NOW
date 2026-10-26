import Foundation

/// Sun and moon positions computed on-device (no internet needed).
/// Based on the formulas from Astronomy Answers (aa.quae.nl), as used by suncalc.
/// Accuracy is well within what we need for drawing a sky (~0.5°).
enum Astronomy {
    private static let rad = Double.pi / 180
    private static let obliquity = rad * 23.4397
    private static let j1970 = 2440588.0
    private static let j2000 = 2451545.0

    struct Position {
        /// Height above the horizon in radians (negative = below).
        var altitude: Double
        /// Direction in radians, measured from SOUTH, positive towards WEST.
        var azimuth: Double
    }

    struct MoonPhase {
        /// 0…1 of the disc that is lit.
        var fraction: Double
        /// 0 = new, 0.25 = first quarter, 0.5 = full, 0.75 = last quarter.
        var phase: Double
    }

    // MARK: - Time

    private static func days(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86400 - 0.5 + j1970 - j2000
    }

    // MARK: - Helpers

    private static func rightAscension(_ l: Double, _ b: Double) -> Double {
        atan2(sin(l) * cos(obliquity) - tan(b) * sin(obliquity), cos(l))
    }

    private static func declination(_ l: Double, _ b: Double) -> Double {
        asin(sin(b) * cos(obliquity) + cos(b) * sin(obliquity) * sin(l))
    }

    private static func azimuth(_ h: Double, _ phi: Double, _ dec: Double) -> Double {
        atan2(sin(h), cos(h) * sin(phi) - tan(dec) * cos(phi))
    }

    private static func altitude(_ h: Double, _ phi: Double, _ dec: Double) -> Double {
        asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(h))
    }

    private static func siderealTime(_ d: Double, _ lw: Double) -> Double {
        rad * (280.16 + 360.9856235 * d) - lw
    }

    private static func sunCoords(_ d: Double) -> (dec: Double, ra: Double) {
        let m = rad * (357.5291 + 0.98560028 * d)
        let c = rad * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m))
        let l = m + c + rad * 102.9372 + Double.pi
        return (declination(l, 0), rightAscension(l, 0))
    }

    private static func moonCoords(_ d: Double) -> (dec: Double, ra: Double, dist: Double) {
        let l = rad * (218.316 + 13.176396 * d)
        let m = rad * (134.963 + 13.064993 * d)
        let f = rad * (93.272 + 13.229350 * d)
        let lon = l + rad * 6.289 * sin(m)
        let lat = rad * 5.128 * sin(f)
        let dist = 385001 - 20905 * cos(m)
        return (declination(lon, lat), rightAscension(lon, lat), dist)
    }

    // MARK: - Public

    static func sun(at date: Date, latitude: Double, longitude: Double) -> Position {
        let lw = rad * -longitude, phi = rad * latitude, d = days(date)
        let c = sunCoords(d)
        let h = siderealTime(d, lw) - c.ra
        return Position(altitude: altitude(h, phi, c.dec), azimuth: azimuth(h, phi, c.dec))
    }

    static func moon(at date: Date, latitude: Double, longitude: Double) -> Position {
        let lw = rad * -longitude, phi = rad * latitude, d = days(date)
        let c = moonCoords(d)
        let h = siderealTime(d, lw) - c.ra
        return Position(altitude: altitude(h, phi, c.dec), azimuth: azimuth(h, phi, c.dec))
    }

    static func moonPhase(at date: Date) -> MoonPhase {
        let d = days(date)
        let s = sunCoords(d), m = moonCoords(d)
        let sunDist = 149_598_000.0
        let phi = acos(sin(s.dec) * sin(m.dec) + cos(s.dec) * cos(m.dec) * cos(s.ra - m.ra))
        let inc = atan2(sunDist * sin(phi), m.dist - sunDist * cos(phi))
        let angle = atan2(cos(s.dec) * sin(s.ra - m.ra),
                          sin(s.dec) * cos(m.dec) - cos(s.dec) * sin(m.dec) * cos(s.ra - m.ra))
        let fraction = (1 + cos(inc)) / 2
        let phase = 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / Double.pi
        return MoonPhase(fraction: fraction, phase: phase)
    }
}
