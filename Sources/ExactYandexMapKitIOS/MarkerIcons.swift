// exact-yandex-mapkit on iOS: marker and cluster icons drawn in code, so the package needs no image assets. The
// drawing, colours and sizes are those of android/MarkerIcons.kt, in points where Android uses dp.
//
// Two marker looks (Props.swift says which a marker gets):
// - 0.2's: a white disc inside a ring in its category's colour (`kind`), with a dot in its status's colour (`status`)
//   at the lower right. A cluster is a disc in the ring colour of its most common kind with its count.
// - 0.3's (Tokens.swift): a paper disc inside a neutral ink ring whose style says the power (`thin`, `thick`, `halo`,
//   `split`), with a centre glyph in the status's colour whose shape repeats the status (`fill`, `ring`, `bar`,
//   `dashed`). With an icon, the icon fills the ring and the glyph moves to the lower right. A cluster is a paper disc
//   with an ink ring and its count, plus a green dot when any of its markers is free.
// Either way the selected marker is larger and carries its `label` underneath. A badge is a paper pill with a dot
// and a border in its tone's colour, and a pointer, drawn above its point so it clears a marker there.
//
// Images are cached by what they show, so a thousand markers of four ring styles and four statuses make sixteen.
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

    // 0.3's look, as fractions of the disc's diameter (thin ring 1.8 pt and thick 3.9 pt on a 30 pt marker).
    private static let thin: CGFloat = 0.06
    private static let thick: CGFloat = 0.13
    private static let halo: CGFloat = 0.05
    private static let haloGap: CGFloat = 0.05
    private static let haloAlpha: CGFloat = 0.55
    private static let glyphFraction: CGFloat = 0.42
    private static let dashes: CGFloat = 8

    // Badges, in points.
    private static let badgePt: CGFloat = 12
    private static let badgeHeight: CGFloat = 22
    private static let badgePad: CGFloat = 8
    private static let badgeDot: CGFloat = 6
    private static let badgeBorder: CGFloat = 1.5
    private static let badgePointer: CGFloat = 5
    /// The empty space under a badge's pointer, so a badge on a marker's point sits just above the marker.
    private static let badgeGap: CGFloat = markerPt / 2 + 1

    /// The side an icon is decoded to: the selected marker's disc.
    static let iconPt: CGFloat = selectedPt

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

    init() { cache.countLimit = 96 }

    /// The marker's image; its anchor is the disc's centre, which `anchorY` gives as a fraction of the height.
    /// `icon` is the marker's decoded icon, or nil while it loads (or when it has none).
    func marker(_ spec: MarkerSpec, selected: Bool, night: Bool, icon: UIImage? = nil) -> UIImage {
        let label = selected ? String(spec.label.prefix(Self.labelMax)) : ""
        if spec.styled {
            let ring = Tokens.ring(spec.ring), glyph = Tokens.glyph(spec.glyph, status: spec.status), tone = Tokens.tone(spec.status)
            let key = "s|\(ring)|\(glyph)|\(tone)|\(selected)|\(night)|\(label)|\(icon != nil ? spec.icon : "")" as NSString
            if let hit = cache.object(forKey: key) { return hit }
            let image = drawStyled(ring: ring, glyph: glyph, tone: tone, selected: selected, night: night, label: label, icon: icon)
            cache.setObject(image, forKey: key)
            return image
        }
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

    /// A 0.3 cluster: paper, an ink ring and the count, with a green dot when any marker in it is free.
    func styledCluster(count: Int, anyFree: Bool, night: Bool) -> UIImage {
        let key = "sc|\(count)|\(anyFree)|\(night)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let image = drawStyledCluster(count: count, anyFree: anyFree, night: night)
        cache.setObject(image, forKey: key)
        return image
    }

    /// A badge's image; its anchor is the bottom centre (0.5, 1), its point.
    func badge(text: String, tone: String, night: Bool) -> UIImage {
        let color = Tokens.tone(tone)
        let key = "b|\(text)|\(color)|\(night)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let image = drawBadge(text: text, tone: color, night: night)
        cache.setObject(image, forKey: key)
        return image
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
            if !label.isEmpty { Self.drawLabel(label, cx: cx, disc: disc, night: night) }
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

    // MARK: 0.3's look

    private func drawStyled(ring: String, glyph: String, tone: ARGB, selected: Bool, night: Bool, label: String, icon: UIImage?) -> UIImage {
        let disc = selected ? Self.selectedPt : Self.markerPt
        let font = UIFont.boldSystemFont(ofSize: Self.labelPt)
        let labelWidth = label.isEmpty ? 0 : (label as NSString).size(withAttributes: [.font: font]).width + 12
        let size = CGSize(width: max(max(disc, labelWidth).rounded(.down), 1),
                          height: max((disc + (label.isEmpty ? 0 : labelHeight)).rounded(.down), 1))
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let cx = size.width / 2, cy = disc / 2, r = disc / 2 - 1
            let ink = Tokens.inkColor(night: night), paper = Tokens.paperColor(night: night)
            Self.fillCircle(cg, cx, cy, r, paper)
            let inner = Self.drawRing(cg, ring, cx, cy, r, disc, ink)
            if let icon {
                Self.drawIcon(cg, icon, cx, cy, inner - 0.5)
                let g = r * 0.34, gx = cx + r * 0.62, gy = cy + r * 0.62
                Self.fillCircle(cg, gx, gy, g + 1.5, paper)
                Self.drawGlyph(cg, glyph, gx, gy, g, tone)
            } else {
                Self.drawGlyph(cg, glyph, cx, cy, r * Self.glyphFraction, tone)
            }
            if !label.isEmpty { Self.drawLabel(label, cx: cx, disc: disc, night: night) }
        }
    }

    private static func fillCircle(_ cg: CGContext, _ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ argb: ARGB) {
        cg.setFillColor(color(argb).cgColor)
        cg.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }

    /// A ring of width `w` whose outer edge is radius `outer`.
    private static func strokeCircle(_ cg: CGContext, _ x: CGFloat, _ y: CGFloat, _ outer: CGFloat, _ w: CGFloat, _ argb: ARGB) {
        let radius = outer - w / 2
        cg.setStrokeColor(color(argb).cgColor)
        cg.setLineWidth(w)
        cg.strokeEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }

    /// Draws the ink ring of style `ring` inside radius `r`; returns the radius left inside it.
    private static func drawRing(_ cg: CGContext, _ ring: String, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ disc: CGFloat, _ ink: ARGB) -> CGFloat {
        cg.setLineDash(phase: 0, lengths: [])
        cg.setLineCap(.butt)
        let thinW = disc * thin, thickW = disc * thick
        switch ring {
        case "thick":
            strokeCircle(cg, cx, cy, r, thickW, ink)
            return r - thickW
        case "halo":
            let haloW = disc * halo
            let faded = (ink & 0x00FF_FFFF) | (UInt32(haloAlpha * 255) << 24)
            strokeCircle(cg, cx, cy, r, haloW, faded)
            let outer = r - haloW - disc * haloGap
            strokeCircle(cg, cx, cy, outer, thickW, ink)
            return outer - thickW
        case "split":
            // Left half thin, right half thick: AC and DC on one site.
            cg.setStrokeColor(color(ink).cgColor)
            let left = UIBezierPath(arcCenter: CGPoint(x: cx, y: cy), radius: r - thinW / 2, startAngle: .pi / 2, endAngle: .pi * 1.5, clockwise: true)
            left.lineWidth = thinW
            left.stroke()
            let right = UIBezierPath(arcCenter: CGPoint(x: cx, y: cy), radius: r - thickW / 2, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
            right.lineWidth = thickW
            right.stroke()
            return r - thickW
        default:
            strokeCircle(cg, cx, cy, r, thinW, ink)
            return r - thinW
        }
    }

    /// The status glyph of radius `g` in `tone`: a filled disc, a thick ring, a ring with a bar, or a dashed ring.
    private static func drawGlyph(_ cg: CGContext, _ glyph: String, _ cx: CGFloat, _ cy: CGFloat, _ g: CGFloat, _ tone: ARGB) {
        cg.setLineDash(phase: 0, lengths: [])
        cg.setLineCap(.butt)
        switch glyph {
        case "ring":
            strokeCircle(cg, cx, cy, g, g * 0.55, tone)
        case "bar":
            let w = g * 0.32
            strokeCircle(cg, cx, cy, g, w, tone)
            let d = (g - w / 2) * 0.7071
            cg.setLineWidth(w)
            cg.move(to: CGPoint(x: cx - d, y: cy + d))
            cg.addLine(to: CGPoint(x: cx + d, y: cy - d))
            cg.strokePath()
        case "dashed":
            let w = g * 0.32, radius = g - w / 2
            let dash = (2 * .pi * radius) / (dashes * 2)
            cg.setLineDash(phase: 0, lengths: [dash, dash])
            strokeCircle(cg, cx, cy, g, w, tone)
            cg.setLineDash(phase: 0, lengths: [])
        default:
            fillCircle(cg, cx, cy, g, tone)
        }
    }

    /// `icon` scaled to cover a circle of radius `radius`, clipped to it.
    private static func drawIcon(_ cg: CGContext, _ icon: UIImage, _ cx: CGFloat, _ cy: CGFloat, _ radius: CGFloat) {
        guard radius > 0, icon.size.width > 0, icon.size.height > 0 else { return }
        let scale = radius * 2 / min(icon.size.width, icon.size.height)
        let w = icon.size.width * scale, h = icon.size.height * scale
        cg.saveGState()
        cg.addEllipse(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
        cg.clip()
        icon.draw(in: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
        cg.restoreGState()
    }

    private static func drawLabel(_ label: String, cx: CGFloat, disc: CGFloat, night: Bool) {
        let font = UIFont.boldSystemFont(ofSize: labelPt)
        // Android draws text from its baseline; UIKit from the top of the line, so lift by the ascender.
        let baseline = disc + labelPt * 1.2
        let width = (label as NSString).size(withAttributes: [.font: font]).width
        let origin = CGPoint(x: cx - width / 2, y: baseline - font.ascender)
        let halo = color(night ? 0xFF111827 : 0xFFFFFFFF), ink = color(night ? 0xFFFFFFFF : 0xFF111827)
        // A positive stroke width strokes only, in points as a percentage of the font size: 3 pt here.
        (label as NSString).draw(at: origin, withAttributes: [.font: font, .strokeColor: halo, .strokeWidth: 3 / labelPt * 100])
        (label as NSString).draw(at: origin, withAttributes: [.font: font, .foregroundColor: ink])
    }

    private func drawStyledCluster(count: Int, anyFree: Bool, night: Bool) -> UIImage {
        let label = count > 999 ? "999+" : String(count)
        let side = (Self.clusterPt * (label.count > 2 ? 1.2 : 1)).rounded(.down)
        let size = CGSize(width: side, height: side)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let c = side / 2, r = c - 1
            let ink = Tokens.inkColor(night: night), paper = Tokens.paperColor(night: night)
            Self.fillCircle(cg, c, c, r, paper)
            Self.strokeCircle(cg, c, c, r, 2.5, ink)
            let font = UIFont.boldSystemFont(ofSize: 13)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Self.color(ink)]
            let text = (label as NSString).size(withAttributes: attrs)
            (label as NSString).draw(at: CGPoint(x: c - text.width / 2, y: c - text.height / 2), withAttributes: attrs)
            if anyFree {
                let dot: CGFloat = 4.5
                let dx = min(c + r * 0.68, side - dot - 1), dy = max(c - r * 0.68, dot + 1)
                Self.fillCircle(cg, dx, dy, dot + 1.5, paper)
                Self.fillCircle(cg, dx, dy, dot, Tokens.free)
            }
        }
    }

    private func drawBadge(text label: String, tone: ARGB, night: Bool) -> UIImage {
        let font = UIFont.boldSystemFont(ofSize: Self.badgePt)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Self.color(Tokens.inkColor(night: night))]
        let textSize = (label as NSString).size(withAttributes: attrs)
        let pad = Self.badgePad, dot = Self.badgeDot, gap: CGFloat = 4, h = Self.badgeHeight
        let border = Self.badgeBorder, pointer = Self.badgePointer
        let w = max(h, pad + dot + gap + textSize.width + pad)
        let size = CGSize(width: (w + 2 * border).rounded(.down) + 1, height: (h + 2 * border + pointer + Self.badgeGap).rounded(.down) + 1)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let cx = size.width / 2
            let pill = CGRect(x: border, y: border, width: w, height: h)
            // The pointer first, so the pill's border runs across its base.
            cg.setFillColor(Self.color(tone).cgColor)
            cg.move(to: CGPoint(x: cx - pointer, y: pill.maxY - border))
            cg.addLine(to: CGPoint(x: cx + pointer, y: pill.maxY - border))
            cg.addLine(to: CGPoint(x: cx, y: pill.maxY + pointer))
            cg.closePath()
            cg.fillPath()
            let shape = UIBezierPath(roundedRect: pill, cornerRadius: h / 2)
            Self.color(Tokens.paperColor(night: night)).setFill()
            shape.fill()
            Self.color(tone).setStroke()
            shape.lineWidth = border
            shape.stroke()
            Self.fillCircle(cg, pill.minX + pad + dot / 2, pill.midY, dot / 2, tone)
            (label as NSString).draw(at: CGPoint(x: pill.minX + pad + dot + gap, y: pill.midY - textSize.height / 2), withAttributes: attrs)
        }
    }
}
