// exact-yandex-mapkit on iOS: what a `yandex-map` tag's props say, read once per update into plain values.
//
// Exact hands an Apple package view every prop as a string, so every read here is lenient: a value that does not
// parse is absent, never a crash. `markers` is a JSON array of {id, lat, lng, kind, status, label, ring, glyph, icon};
// `badges` is a JSON array of {id, lat, lng, text, tone}. An entry without an id or finite coordinates is skipped, as
// is a repeated id. The defaults match android/Props.kt.
import Foundation

/// One marker the app placed. `label` is read aloud and drawn under the selected marker.
///
/// Two looks. A marker with none of `ring`, `glyph` and `icon` keeps 0.2's: a ring in `kind`'s colour and a dot in
/// `status`'s. A marker with any of them is drawn in 0.3's: a neutral ring whose style is `ring`
/// (`thin|thick|halo|split`), a centre glyph whose shape is `glyph` (`fill|ring|bar|dashed`, by default the status's
/// own) in `status`'s colour, and, with `icon` (a `data:` or `https:` image), that image inside the ring.
struct MarkerSpec: Equatable {
    let id: String
    let lat: Double
    let lng: Double
    let kind: String
    let status: String
    let label: String
    var ring = ""
    var glyph = ""
    var icon = ""

    /// Drawn in 0.3's look.
    var styled: Bool { !ring.isEmpty || !glyph.isEmpty || !icon.isEmpty }
}

/// One text badge: a small unclustered pill above a point, its dot and border in `tone`'s colour.
struct BadgeSpec: Equatable {
    let id: String
    let lat: Double
    let lng: Double
    let text: String
    let tone: String
}

/// Every prop of one `yandex-map`, with the defaults the README documents.
struct MapProps: Equatable {
    static let defaultClusterRadius = 50.0
    static let defaultClusterMinZoom = 14
    static let defaultFitPadding = 48.0
    static let defaultPolylineWidth = 5.0
    static let maxPolylineWidth = 24.0
    static let badgeTextMax = 24

    var apiKey = ""
    var lat: Double?
    var lng: Double?
    var zoom: Double?
    var markersJson = ""
    var markersVersion = ""
    var selectedId = ""
    var clustering = true
    var clusterRadius = MapProps.defaultClusterRadius
    var clusterMinZoom = MapProps.defaultClusterMinZoom
    var showUser = false
    var night = false
    var polyline = ""
    var polylineColor = ""
    var polylineDash = false
    var polylineWidth = MapProps.defaultPolylineWidth
    var badgesJson = ""
    var fitKey = ""
    var fitPadding = MapProps.defaultFitPadding
    var label = ""

    /// The markers `markersJson` names, parsed on demand (only when the markers changed).
    func markers() -> [MarkerSpec] { MapProps.parseMarkers(markersJson) }

    /// The badges `badgesJson` names, parsed on demand (only when they changed).
    func badges() -> [BadgeSpec] { MapProps.parseBadges(badgesJson) }

    static func from(_ props: [String: String]) -> MapProps {
        var p = MapProps()
        p.apiKey = text(props["apiKey"]).trimmingCharacters(in: .whitespacesAndNewlines)
        p.lat = number(props["lat"])
        p.lng = number(props["lng"])
        p.zoom = number(props["zoomLevel"])
        p.markersJson = text(props["markers"])
        p.markersVersion = text(props["markersVersion"])
        p.selectedId = text(props["selectedId"])
        p.clustering = flag(props["clustering"]) ?? true
        if let r = number(props["clusterRadius"]), r > 0 { p.clusterRadius = r }
        if let z = number(props["clusterMinZoom"]) { p.clusterMinZoom = Int(min(max(z, 0), 21)) }
        p.showUser = flag(props["showUser"]) ?? false
        p.night = flag(props["night"]) ?? false
        p.polyline = text(props["polyline"])
        p.polylineColor = text(props["polylineColor"])
        p.polylineDash = flag(props["polylineDash"]) ?? false
        if let w = number(props["polylineWidth"]), w > 0 { p.polylineWidth = min(w, maxPolylineWidth) }
        p.badgesJson = text(props["badges"])
        p.fitKey = text(props["fitKey"])
        if let pad = number(props["fitPadding"]) { p.fitPadding = max(pad, 0) }
        p.label = text(props["aria-label"])
        return p
    }

    static func parseMarkers(_ json: String) -> [MarkerSpec] {
        guard let list = jsonArray(json) else { return [] }
        var out: [MarkerSpec] = []
        var seen = Set<String>()
        for item in list {
            guard let o = item as? [String: Any] else { continue }
            let id = jsonText(o["id"])
            guard !id.isEmpty, let lat = jsonNumber(o["lat"]), let lng = jsonNumber(o["lng"]), seen.insert(id).inserted else { continue }
            let trimmed = { (key: String) in jsonText(o[key]).trimmingCharacters(in: .whitespacesAndNewlines) }
            out.append(MarkerSpec(id: id, lat: lat, lng: lng, kind: jsonText(o["kind"]), status: jsonText(o["status"]), label: jsonText(o["label"]),
                                  ring: trimmed("ring").lowercased(), glyph: trimmed("glyph").lowercased(), icon: trimmed("icon")))
        }
        return out
    }

    static func parseBadges(_ json: String) -> [BadgeSpec] {
        guard let list = jsonArray(json) else { return [] }
        var out: [BadgeSpec] = []
        var seen = Set<String>()
        for item in list {
            guard let o = item as? [String: Any] else { continue }
            let id = jsonText(o["id"])
            let text = String(jsonText(o["text"]).trimmingCharacters(in: .whitespacesAndNewlines).prefix(badgeTextMax))
            guard !id.isEmpty, !text.isEmpty, let lat = jsonNumber(o["lat"]), let lng = jsonNumber(o["lng"]), seen.insert(id).inserted else { continue }
            out.append(BadgeSpec(id: id, lat: lat, lng: lng, text: text, tone: jsonText(o["tone"])))
        }
        return out
    }

    private static func jsonArray(_ json: String) -> [Any]? {
        guard !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let data = json.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [Any]
    }

    // MARK: lenient reads

    private static func text(_ v: String?) -> String {
        guard let v, v != "null" else { return "" }
        return v
    }

    private static func number(_ v: String?) -> Double? {
        guard let v, let d = Double(v.trimmingCharacters(in: .whitespacesAndNewlines)), d.isFinite else { return nil }
        return d
    }

    private static func flag(_ v: String?) -> Bool? {
        guard let v, v != "null" else { return nil }
        switch v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "1": return true
        case "false", "0", "": return false
        default:
            if let d = Double(v) { return d != 0 }
            return nil
        }
    }

    private static func jsonText(_ v: Any?) -> String {
        switch v {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        default: return ""
        }
    }

    private static func jsonNumber(_ v: Any?) -> Double? {
        let d: Double?
        switch v {
        case let n as NSNumber: d = CFGetTypeID(n) == CFBooleanGetTypeID() ? nil : n.doubleValue
        case let s as String: d = Double(s.trimmingCharacters(in: .whitespacesAndNewlines))
        default: d = nil
        }
        guard let d, d.isFinite else { return nil }
        return d
    }
}
