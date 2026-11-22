// exact-yandex-mapkit on iOS: the colours and names of 0.3's marker look, shared by markers, clusters and badges. The
// same table as android/Tokens.kt.
//
// Hue means availability only: four status colours, each with its own glyph shape, so a colour-blind reader loses
// nothing. Power is the ring's style, drawn in a neutral ink. The colours are fixed (Yandex's tiles do not follow the
// app's theme); `night` swaps the paper and the ink, never a status colour.
import Foundation

enum Tokens {
    static let free: ARGB = 0xFF0A8754
    static let busy: ARGB = 0xFFB86E00
    static let offline: ARGB = 0xFFA8321A
    static let unknown: ARGB = 0xFF7C838D
    static let accent: ARGB = 0xFF2348C8

    static let ink: ARGB = 0xFF0B1512
    static let paper: ARGB = 0xFFFFFFFF
    static let nightInk: ARGB = 0xFFE8EBEF
    static let nightPaper: ARGB = 0xFF171A1F

    /// The ring styles, and the one a styled marker without a known `ring` gets.
    static let rings: Set<String> = ["thin", "thick", "halo", "split"]
    static let defaultRing = "thin"

    /// The glyph shapes.
    static let glyphs: Set<String> = ["fill", "ring", "bar", "dashed"]

    private static let classes: [String: String] = [
        "free": "free", "available": "free", "online": "free", "ok": "free",
        "busy": "busy", "occupied": "busy", "charging": "busy", "in_use": "busy", "tight": "busy",
        "offline": "offline", "unavailable": "offline", "broken": "offline", "maintenance": "offline",
        "out_of_order": "offline", "short": "offline",
    ]

    /// `free`, `busy`, `offline` or `unknown` for a status (or badge tone) name; `""` for no status. A `#rrggbb` value
    /// is `custom`.
    static func statusClass(_ status: String) -> String {
        let s = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.isEmpty { return "" }
        if s.hasPrefix("#") { return "custom" }
        return classes[s] ?? "unknown"
    }

    /// The colour a status (or badge tone) is drawn in. `accent` is the brand blue; a `#rrggbb` value is used as
    /// written; anything else unrecognised is grey.
    static func tone(_ status: String) -> ARGB {
        let s = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s == "accent" { return accent }
        if s.hasPrefix("#") { return MarkerIcons.parseColor(s) ?? unknown }
        switch statusClass(s) {
        case "free": return free
        case "busy": return busy
        case "offline": return offline
        default: return unknown
        }
    }

    /// The ring style to draw: `ring` when it is one, else `defaultRing`.
    static func ring(_ ring: String) -> String { rings.contains(ring) ? ring : defaultRing }

    /// The glyph to draw: `glyph` when it is one, else the status's own (free: filled disc, busy: thick ring,
    /// offline: ring with a bar, unknown or none: dashed ring).
    static func glyph(_ glyph: String, status: String) -> String {
        if glyphs.contains(glyph) { return glyph }
        switch statusClass(status) {
        case "free", "custom": return "fill"
        case "busy": return "ring"
        case "offline": return "bar"
        default: return "dashed"
        }
    }

    static func inkColor(night: Bool) -> ARGB { night ? nightInk : ink }
    static func paperColor(night: Bool) -> ARGB { night ? nightPaper : paper }
}
