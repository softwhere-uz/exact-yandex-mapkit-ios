// exact-yandex-mapkit on iOS: marker and cluster icons drawn in code, so the package needs no image assets. The
// drawing, colours and sizes are those of android/MarkerIcons.kt, in points where Android uses dp.
//
// A marker is a white disc inside a ring in its category's colour (`kind`), with a dot in its status's colour
// (`status`) at the lower right; the selected marker is larger and carries its `label` underneath. A cluster is a
// disc in the ring colour of its most common kind with its count. Images are cached by what they show, so a
// thousand markers of four kinds and three statuses make twelve images.
import UIKit

/// A colour as 0xAARRGGBB, as Android's colour ints are, so both platforms share the tables and the hash.
typealias ARGB = UInt32

final class MarkerIcons {
    private static let markerPt: CGFloat = 30
    private static let selectedPt: CGFloat = 40
    private static let clusterPt: CGFloat = 38
    private static let ringFraction: CGFloat = 0.16
    private static let dotFraction: CGFloat = 0.34
    private static let labelPt: CGFloat = 12
    private static let labelMax = 28

    /// Ring colours for common kinds; any `#rrggbb` kind is used as written, any other string gets a stable colour
    /// from `palette`.
    private static let kinds: [String: ARGB] = [
        "dc": 0xFFF97316, "fast": 0xFFF97316, "ccs": 0xFFF97316, "chademo": 0xFFEA580C,
        "gbt": 0xFFDC2626, "ac": 0xFF2563EB, "type2": 0xFF2563EB, "slow": 0xFF16A34A,
        "fuel": 0xFF7C3AED, "service": 0xFF0891B2,
    ]
    private static let palette: [ARGB] = [0xFF2563EB, 0xFFF97316, 0xFF16A34A, 0xFF7C3AED, 0xFF0891B2, 0xFFDB2777]
    private static let defaultKind: ARGB = 0xFF6B7280

    private static let statuses: [String: ARGB] = [
        "available": 0xFF22C55E, "free": 0xFF22C55E, "online": 0xFF22C55E,
        "busy": 0xFFF59E0B, "occupied": 0xFFF59E0B, "charging": 0xFFF59E0B,
        "offline": 0xFFEF4444, "unavailable": 0xFFEF4444, "broken": 0xFFEF4444,
    ]
    private static let unknownStatus: ARGB = 0xFF9CA3AF

    static func kindColor(_ kind: String) -> ARGB {
        let k = kind.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if k.isEmpty { return defaultKind }
        if let c = kinds[k] { return c }
        if k.hasPrefix("#"), let c = parseColor(k) { return c }
        let n = Int32(palette.count)
        return palette[Int(((javaHash(k) % n) + n) % n)]
    }

    static func statusColor(_ status: String) -> ARGB? {
        let s = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.isEmpty { return nil }
        if let c = statuses[s] { return c }
        return s.hasPrefix("#") ? parseColor(s) : unknownStatus
    }

    /// `#rrggbb` or `#aarrggbb`, as Android's `Color.parseColor` reads them; anything else is nil.
    static func parseColor(_ text: String) -> ARGB? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("#"), let v = UInt32(t.dropFirst(), radix: 16) else { return nil }
        switch t.count {
        case 7: return 0xFF00_0000 | v
        case 9: return v
        default: return nil
        }
    }

    /// Java's `String.hashCode`, over UTF-16 units with 32-bit wrapping, so a kind gets the colour it gets on Android.
    static func javaHash(_ s: String) -> Int32 {
        var h: Int32 = 0
        for unit in s.utf16 { h = h &* 31 &+ Int32(unit) }
        return h
    }

    static func color(_ argb: ARGB) -> UIColor {
        UIColor(red: CGFloat((argb >> 16) & 0xFF) / 255, green: CGFloat((argb >> 8) & 0xFF) / 255,
                blue: CGFloat(argb & 0xFF) / 255, alpha: CGFloat((argb >> 24) & 0xFF) / 255)
    }

    private let cache = NSCache<NSString, UIImage>()

    init() { cache.countLimit = 64 }

    /// The marker's image; its anchor is the disc's centre, which `anchorY` gives as a fraction of the height.
    func marker(_ spec: MarkerSpec, selected: Bool, night: Bool) -> UIImage {
        let label = selected ? String(spec.label.prefix(Self.labelMax)) : ""
        let ring = Self.kindColor(spec.kind), status = Self.statusColor(spec.status)
        let key = "m|\(ring)|\(status.map { String($0) } ?? "-")|\(selected)|\(night)|\(label)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let image = drawMarker(ring: ring, status: status, selected: selected, night: night, label: label)
        cache.setObject(image, forKey: key)
        return image
    }

    /// Where the disc's centre sits in `marker`'s image, as a fraction of its height.
    func anchorY(selected: Bool, hasLabel: Bool) -> CGFloat {
        guard selected, hasLabel else { return 0.5 }
        let disc = Self.selectedPt
        return (disc / 2) / (disc + labelHeight)
    }

    func cluster(count: Int, color: ARGB) -> UIImage {
        let key = "c|\(count)|\(color)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let image = drawCluster(count: count, color: color)
        cache.setObject(image, forKey: key)
        return image
    }

    private var labelHeight: CGFloat { Self.labelPt * 1.6 }

    private func drawMarker(ring: ARGB, status: ARGB?, selected: Bool, night: Bool, label: String) -> UIImage {
        let disc = selected ? Self.selectedPt : Self.markerPt
        let font = UIFont.boldSystemFont(ofSize: Self.labelPt)
        let labelWidth = label.isEmpty ? 0 : (label as NSString).size(withAttributes: [.font: font]).width + 12
        let size = CGSize(width: max(max(disc, labelWidth).rounded(.down), 1),
                          height: max((disc + (label.isEmpty ? 0 : labelHeight)).rounded(.down), 1))
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let cx = size.width / 2, cy = disc / 2, r = disc / 2 - 1
            func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ argb: ARGB) {
                cg.setFillColor(Self.color(argb).cgColor)
                cg.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            }
            circle(cx, cy, r, ring)
            circle(cx, cy, r * (1 - Self.ringFraction * 2), night ? 0xFF1F2937 : 0xFFFFFFFF)
            if let status {
                let dotR = r * Self.dotFraction
                let dx = min(cx + r * 0.62, size.width - dotR - 1), dy = min(cy + r * 0.62, disc - dotR - 1)
                circle(dx, dy, dotR + 1.5, night ? 0xFF111827 : 0xFFFFFFFF)
                circle(dx, dy, dotR, status)
            }
            if !label.isEmpty {
                // Android draws text from its baseline; UIKit from the top of the line, so lift by the ascender.
                let baseline = disc + Self.labelPt * 1.2
                let width = (label as NSString).size(withAttributes: [.font: font]).width
                let origin = CGPoint(x: cx - width / 2, y: baseline - font.ascender)
                let halo = Self.color(night ? 0xFF111827 : 0xFFFFFFFF), ink = Self.color(night ? 0xFFFFFFFF : 0xFF111827)
                // A positive stroke width strokes only, in points as a percentage of the font size: 3 pt here.
                (label as NSString).draw(at: origin, withAttributes: [.font: font, .strokeColor: halo,
                                                                       .strokeWidth: 3 / Self.labelPt * 100])
                (label as NSString).draw(at: origin, withAttributes: [.font: font, .foregroundColor: ink])
            }
        }
    }

    private func drawCluster(count: Int, color: ARGB) -> UIImage {
        let label = count > 999 ? "999+" : String(count)
        let side = (Self.clusterPt * (label.count > 2 ? 1.2 : 1)).rounded(.down)
        let size = CGSize(width: side, height: side)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let c = side / 2
            cg.setFillColor(UIColor.white.cgColor)
            cg.fillEllipse(in: CGRect(x: 1, y: 1, width: side - 2, height: side - 2))
            cg.setFillColor(Self.color(color).cgColor)
            cg.fillEllipse(in: CGRect(x: 3.5, y: 3.5, width: side - 7, height: side - 7))
            let font = UIFont.boldSystemFont(ofSize: 13)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
            let text = (label as NSString).size(withAttributes: attrs)
            (label as NSString).draw(at: CGPoint(x: c - text.width / 2, y: c - text.height / 2), withAttributes: attrs)
        }
    }
}
