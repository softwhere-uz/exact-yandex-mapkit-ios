// exact-yandex-mapkit on iOS: the markers of one map, in a YMKClusterizedPlacemarkCollection (or a plain collection
// when clustering is off), plus the selected marker drawn larger, on top and never clustered. As android/MarkerLayer.kt.
//
// MapKit holds every listener weakly; this object is the listener for its collections and clusters, and the map
// keeps it. A tap on a marker reports its id and is consumed, so it never also reaches the map as a press; a tap on a
// cluster zooms in to its markers.
import UIKit
import YandexMapsMobile

final class MarkerLayer: NSObject, YMKMapObjectTapListener, YMKClusterListener, YMKClusterTapListener {
    private static let selectedZ: Float = 100

    private let root: YMKMapObjectCollection
    private let icons: MarkerIcons
    private let onMarker: (String) -> Void
    private let onCluster: ([YMKPoint]) -> Void

    private var clustered: YMKClusterizedPlacemarkCollection?
    private var plain: YMKMapObjectCollection?
    private let selection: YMKMapObjectCollection
    private var specs: [String: MarkerSpec] = [:]
    private var order: [String] = []
    private var night = false
    private var selectedId = ""

    init(root: YMKMapObjectCollection, icons: MarkerIcons, onMarker: @escaping (String) -> Void, onCluster: @escaping ([YMKPoint]) -> Void) {
        self.root = root
        self.icons = icons
        self.onMarker = onMarker
        self.onCluster = onCluster
        selection = root.add()
        super.init()
        selection.zIndex = Self.selectedZ
        selection.addTapListener(with: self)
    }

    /// Every marker's position, for a camera fit.
    func points() -> [YMKPoint] {
        order.compactMap { specs[$0] }.map { YMKPoint(latitude: $0.lat, longitude: $0.lng) }
    }

    /// Rebuilds the placemarks: called only when `markers`, `markersVersion`, clustering or night changed.
    func set(_ markers: [MarkerSpec], clustering: Bool, clusterRadius: Double, clusterMinZoom: Int, night nightMode: Bool) {
        specs = Dictionary(markers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        order = markers.map(\.id)
        night = nightMode
        clear()
        let style = YMKIconStyle()
        style.anchor = NSValue(cgPoint: CGPoint(x: 0.5, y: 0.5))
        let add: () -> YMKPlacemarkMapObject
        if clustering {
            let c = root.addClusterizedPlacemarkCollection(with: self)
            clustered = c
            c.addTapListener(with: self)
            add = { c.addPlacemark() }
        } else {
            let c = root.add()
            plain = c
            c.addTapListener(with: self)
            add = { c.addPlacemark() }
        }
        for spec in markers {
            let placemark = add()
            placemark.geometry = YMKPoint(latitude: spec.lat, longitude: spec.lng)
            placemark.setIconWith(icons.marker(spec, selected: false, night: night), style: style)
            placemark.userData = spec.id
        }
        clustered?.clusterPlacemarks(withClusterRadius: clusterRadius, minZoom: UInt(clusterMinZoom))
        select(selectedId, force: true)
    }

    /// Draws `id`'s marker selected (or none for "").
    func select(_ id: String, force: Bool = false) {
        if id == selectedId && !force { return }
        selectedId = id
        selection.clear()
        guard let spec = specs[id] else { return }
        let style = YMKIconStyle()
        style.anchor = NSValue(cgPoint: CGPoint(x: 0.5, y: icons.anchorY(selected: true, hasLabel: !spec.label.isEmpty)))
        style.zIndex = NSNumber(value: Self.selectedZ)
        let placemark = selection.addPlacemark()
        placemark.geometry = YMKPoint(latitude: spec.lat, longitude: spec.lng)
        placemark.setIconWith(icons.marker(spec, selected: true, night: night), style: style)
        placemark.userData = spec.id
    }

    func clear() {
        if let c = clustered { root.remove(with: c) }
        if let c = plain { root.remove(with: c) }
        clustered = nil
        plain = nil
        selection.clear()
    }

    // MARK: YMKMapObjectTapListener

    func onMapObjectTap(with mapObject: YMKMapObject, point: YMKPoint) -> Bool {
        guard let id = mapObject.userData as? String else { return false }
        onMarker(id)
        return true
    }

    // MARK: YMKClusterListener, YMKClusterTapListener

    func onClusterAdded(with cluster: YMKCluster) {
        cluster.appearance.setIconWith(icons.cluster(count: Int(cluster.size), color: clusterColor(cluster)))
        cluster.addClusterTapListener(with: self)
    }

    func onClusterTap(with cluster: YMKCluster) -> Bool {
        onCluster(cluster.placemarks.map(\.geometry))
        return true
    }

    /// The ring colour of the kind most of the cluster's markers share.
    private func clusterColor(_ cluster: YMKCluster) -> ARGB {
        var kinds: [String: Int] = [:]
        var first: [String] = []
        for p in cluster.placemarks {
            guard let id = p.userData as? String, let kind = specs[id]?.kind else { continue }
            if kinds[kind] == nil { first.append(kind) }
            kinds[kind, default: 0] += 1
        }
        // The most common kind; a tie goes to the kind seen first, so the colour does not flicker between redraws.
        let top = first.max { (kinds[$0] ?? 0) < (kinds[$1] ?? 0) } ?? ""
        return MarkerIcons.kindColor(top)
    }
}
