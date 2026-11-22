// exact-yandex-mapkit on iOS: Google's encoded polyline format at precision 5 (what OSRM, Valhalla and most routing
// APIs return), decoded to coordinates. A malformed tail ends the line where it breaks. Same decoder as
// android/Polyline.kt.
import Foundation

enum Polyline5 {
    private static let precision = 1e5

    static func decode(_ encoded: String) -> [(lat: Double, lng: Double)] {
        let bytes = Array(encoded.utf8)
        var points: [(lat: Double, lng: Double)] = []
        var index = 0
        // 32-bit and wrapping, as Kotlin's Int is in android/Polyline.kt, so both platforms read a bad line alike.
        var lat: Int32 = 0
        var lng: Int32 = 0
        while index < bytes.count {
            guard let dLat = next(bytes, index) else { break }
            index = dLat.end
            guard let dLng = next(bytes, index) else { break }
            index = dLng.end
            lat &+= dLat.value
            lng &+= dLng.value
            points.append((Double(lat) / precision, Double(lng) / precision))
        }
        return points
    }

    /// One zig-zag varint from `at`: its value and the index after it, or nil when the string ends inside it.
    private static func next(_ s: [UInt8], _ at: Int) -> (value: Int32, end: Int)? {
        var result: Int32 = 0
        var shift: Int32 = 0
        var i = at
        while true {
            if i >= s.count { return nil }
            let b = Int32(s[i]) - 63
            i += 1
            if b < 0 || shift > 30 { return nil }
            result |= (b & 0x1f) << shift
            shift += 5
            if b < 0x20 { break }
        }
        let value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        return (value, i)
    }
}
