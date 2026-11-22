// exact-yandex-mapkit on iOS: what a `yandex-map` tag's props say, read once per update into plain values.
//
// Exact hands an Apple package view every prop as a string, so every read here is lenient: a value that does not
// parse is absent, never a crash. `markers` is a JSON array of {id, lat, lng, kind, status, label}; an entry without
// an id or finite coordinates is skipped, as is a repeated id. The defaults match android/Props.kt.
import Foundation

/// One marker the app placed. `kind` picks the ring's colour, `status` the dot's, `label` is read aloud and drawn
/// under the selected marker.
struct MarkerSpec: Equatable {
    let id: String
    let lat: Double
    let lng: Double
    let kind: String
    let status: String
    let label: String
}

/// Every prop of one `yandex-map`, with the defaults the README documents.
struct MapProps: Equatable {
    static let defaultClusterRadius = 50.0
    static let defaultClusterMinZoom = 14
    static let defaultFitPadding = 48.0

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
    var fitKey = ""
    var fitPadding = MapProps.defaultFitPadding
    var label = ""

    /// The markers `markersJson` names, parsed on demand (only when the markers changed).
    func markers() -> [MarkerSpec] { MapProps.parseMarkers(markersJson) }

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
        p.fitKey = text(props["fitKey"])
        if let pad = number(props["fitPadding"]) { p.fitPadding = max(pad, 0) }
        p.label = text(props["aria-label"])
        return p
    }

    static func parseMarkers(_ json: String) -> [MarkerSpec] {
        guard !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let data = json.data(using: .utf8),
              let list = (try? JSONSerialization.jsonObject(with: data)) as? [Any] else { return [] }
        var out: [MarkerSpec] = []
        var seen = Set<String>()
        for item in list {
            guard let o = item as? [String: Any] else { continue }
            let id = jsonText(o["id"])
            guard !id.isEmpty, let lat = jsonNumber(o["lat"]), let lng = jsonNumber(o["lng"]), seen.insert(id).inserted else { continue }
            out.append(MarkerSpec(id: id, lat: lat, lng: lng, kind: jsonText(o["kind"]), status: jsonText(o["status"]), label: jsonText(o["label"])))
        }
        return out
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
