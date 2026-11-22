// exact-yandex-mapkit on iOS: one `yandex-map`, its YMKMapView, and what it tells the app. As android/OneYandexMap.kt.
//
// - The camera props (`lat`, `lng`, `zoomLevel`) move the map only when their value changes, and only that prop, so
//   a person's pan is not undone by an unrelated update. The first values place the camera without animation.
// - `fitKey`: each new non-empty value fits the camera to the route polyline, or to the markers when there is no
//   polyline, inset by `fitPadding` points. A fit asked before the view has a size runs once it has one.
// - Markers are rebuilt only when `markers`, `markersVersion`, clustering or night mode changed.
// - Events go to `emit` as a name and one payload, which the Exact package sends as declared events:
//   `cameraChange {lat, lng, zoom}` when the camera comes to rest, whoever moved it; `markerPress {id}` for a tap on a marker; `mapPress {lat, lng}` for a tap on
//   the map away from any marker.
import CoreLocation
import UIKit
import YandexMapsMobile

/// The view Exact places: it holds the map and says when it has been laid out, so a fit can wait for a size.
final class MapHost: UIView {
    var laidOut: () -> Void = {}
    override func layoutSubviews() {
        super.layoutSubviews()
        laidOut()
    }
}

final class OneYandexMap: NSObject, YMKMapCameraListener, YMKMapInputListener, YMKMapSizeChangedListener {
    private static let moveSeconds: Float = 0.35
    private static let fitSeconds: Float = 0.5
    private static let defaultZoom: Float = 12
    private static let maxFitZoom: Float = 17
    private static let polylineWidth: Float = 5
    private static let defaultRouteColor: ARGB = 0xFF2563EB

    let id: String
    private let emit: (String, [String: Any]) -> Void
    private let log: (String) -> Void
    private let host = MapHost(frame: .zero)
    private let mapView: YMKMapView
    private let icons = MarkerIcons()
    private var markers: MarkerLayer!
    private var route: YMKPolylineMapObject?
    private var routePoints: [YMKPoint] = []
    private var userLayer: YMKUserLocationLayer?
    private var props: MapProps?
    private var pendingFit = false

    private var map: YMKMap { mapView.mapWindow.map }

    /// Whether MapKit's own window has a size yet. It follows the view's size a little later, on MapKit's render
    /// thread, and MapKit stops the app ("Map should have size > 0") when a camera is fitted before it has one.
    private var hasSize: Bool { mapView.mapWindow.width() > 0 && mapView.mapWindow.height() > 0 }

    init(id: String, emit: @escaping (String, [String: Any]) -> Void, log: @escaping (String) -> Void) {
        self.id = id
        self.emit = emit
        self.log = log
        mapView = YMKMapView(frame: .zero)
        super.init()
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.frame = host.bounds
        host.addSubview(mapView)
        host.clipsToBounds = true
        markers = MarkerLayer(root: map.mapObjects, icons: icons,
                              onMarker: { [weak self] in self?.markerTapped($0) },
                              onCluster: { [weak self] in self?.clusterTapped($0) })
        map.addCameraListener(with: self)
        map.addInputListener(with: self)
        mapView.mapWindow.addSizeChangedListener(with: self)
        host.laidOut = { [weak self] in
            guard let self, self.pendingFit, self.host.bounds.width > 0, self.host.bounds.height > 0 else { return }
            self.fit()
        }
    }

    var view: UIView { host }

    func setProps(_ raw: [String: String]) {
        let next = MapProps.from(raw)
        let prev = props
        props = next
        let first = prev == nil
        if first || prev?.night != next.night { map.isNightModeEnabled = next.night }
        moveCamera(prev, next)
        if first || prev?.markersJson != next.markersJson || prev?.markersVersion != next.markersVersion ||
            prev?.clustering != next.clustering || prev?.clusterRadius != next.clusterRadius ||
            prev?.clusterMinZoom != next.clusterMinZoom || prev?.night != next.night {
            markers.set(next.markers(), clustering: next.clustering, clusterRadius: next.clusterRadius,
                        clusterMinZoom: next.clusterMinZoom, night: next.night)
        }
        markers.select(next.selectedId)
        if first || prev?.polyline != next.polyline || prev?.polylineColor != next.polylineColor { drawRoute(next) }
        if first || prev?.showUser != next.showUser { applyUser(next.showUser) }
        if !next.fitKey.isEmpty && next.fitKey != prev?.fitKey { pendingFit = true; fit() }
        if !next.label.isEmpty {
            host.isAccessibilityElement = true
            host.accessibilityLabel = next.label
        }
    }

    /// The app came back to the foreground: a location permission may have been granted meanwhile.
    func foreground() {
        if props?.showUser == true { applyUser(true) }
    }

    func destroy() {
        map.removeCameraListener(with: self)
        map.removeInputListener(with: self)
        mapView.mapWindow.removeSizeChangedListener(with: self)
        markers.clear()
        userLayer?.setVisibleWithOn(false)
    }

    // MARK: camera

    private func moveCamera(_ prev: MapProps?, _ next: MapProps) {
        let first = prev == nil
        let lat = (first || next.lat != prev?.lat) ? next.lat : nil
        let lng = (first || next.lng != prev?.lng) ? next.lng : nil
        let zoom = (first || next.zoom != prev?.zoom) ? next.zoom : nil
        if lat == nil && lng == nil && zoom == nil { return }
        let current = map.cameraPosition
        let target = YMKPoint(latitude: lat ?? current.target.latitude, longitude: lng ?? current.target.longitude)
        let position = YMKCameraPosition(target: target, zoom: zoom.map { Float($0) } ?? (first ? Self.defaultZoom : current.zoom),
                                         azimuth: current.azimuth, tilt: current.tilt)
        if first {
            map.move(with: position)
        } else {
            map.move(with: position, animation: YMKAnimation(type: .smooth, duration: Self.moveSeconds), cameraCallback: nil)
        }
    }

    private func drawRoute(_ next: MapProps) {
        let line = next.polyline.trimmingCharacters(in: .whitespacesAndNewlines)
        routePoints = line.isEmpty ? [] : Polyline5.decode(line).map { YMKPoint(latitude: $0.lat, longitude: $0.lng) }
        if routePoints.count < 2 {
            if let r = route { map.mapObjects.remove(with: r) }
            route = nil
            return
        }
        let object = route ?? map.mapObjects.addPolyline()
        route = object
        object.geometry = YMKPolyline(points: routePoints)
        let color = MarkerIcons.parseColor(next.polylineColor) ?? Self.defaultRouteColor
        object.setStrokeColorWith(MarkerIcons.color(color))
        let style = YMKLineStyle()
        style.strokeWidth = Self.polylineWidth
        style.outlineColor = .white
        style.outlineWidth = 1.5
        object.style = style
        object.zIndex = 10
    }

    private func applyUser(_ show: Bool) {
        let status = CLLocationManager().authorizationStatus
        let allowed = status == .authorizedWhenInUse || status == .authorizedAlways
        if show && !allowed { log("map \(id): showUser without a location permission, so no user location") }
        if !show || !allowed {
            userLayer?.setVisibleWithOn(false)
            return
        }
        let layer = userLayer ?? YMKMapKit.sharedInstance().createUserLocationLayer(with: mapView.mapWindow)
        userLayer = layer
        layer.setVisibleWithOn(true)
        layer.isHeadingModeActive = false
    }

    /// Fits the camera to the route, else the markers; waits for a size when the view has none yet.
    private func fit() {
        guard let p = props, host.bounds.width > 0, host.bounds.height > 0, hasSize else { return }
        pendingFit = false
        let points = routePoints.isEmpty ? markers.points() : routePoints
        guard !points.isEmpty else { return }
        let current = map.cameraPosition
        let target: YMKCameraPosition
        if points.count == 1 {
            target = YMKCameraPosition(target: points[0], zoom: max(current.zoom, Self.defaultZoom), azimuth: current.azimuth, tilt: current.tilt)
        } else {
            let fitted = map.cameraPosition(with: YMKGeometry(boundingBox: Self.box(points)), focus: focus(p.fitPadding),
                                            azimuth: NSNumber(value: current.azimuth), tilt: NSNumber(value: current.tilt))
            target = fitted.zoom > Self.maxFitZoom
                ? YMKCameraPosition(target: fitted.target, zoom: Self.maxFitZoom, azimuth: fitted.azimuth, tilt: fitted.tilt)
                : fitted
        }
        map.move(with: target, animation: YMKAnimation(type: .smooth, duration: Self.fitSeconds), cameraCallback: nil)
    }

    private static func box(_ points: [YMKPoint]) -> YMKBoundingBox {
        let lats = points.map(\.latitude), lngs = points.map(\.longitude)
        return YMKBoundingBox(southWest: YMKPoint(latitude: lats.min()!, longitude: lngs.min()!),
                              northEast: YMKPoint(latitude: lats.max()!, longitude: lngs.max()!))
    }

    /// The view inset by `padding` points, in the map window's physical pixels, kept strictly inside the window as
    /// MapKit requires.
    private func focus(_ padding: Double) -> YMKScreenRect {
        let w = Float(mapView.mapWindow.width()), h = Float(mapView.mapWindow.height())
        let inset = Float(padding) * mapView.mapWindow.scaleFactor
        let left = min(max(inset, 0), w - 2), top = min(max(inset, 0), h - 2)
        let right = min(max(w - inset, left + 1), w - 1), bottom = min(max(h - inset, top + 1), h - 1)
        return YMKScreenRect(topLeft: YMKScreenPoint(x: left, y: top), bottomRight: YMKScreenPoint(x: right, y: bottom))
    }

    private func markerTapped(_ markerId: String) {
        log("map \(id): markerPress \(markerId)")
        emit("markerPress", ["id": markerId])
    }

    private func clusterTapped(_ points: [YMKPoint]) {
        guard !points.isEmpty, hasSize else { return }
        let current = map.cameraPosition
        let geometry = YMKGeometry(boundingBox: Self.box(points))
        let fitted = mapView.mapWindow.width() > 2 && mapView.mapWindow.height() > 2
            ? map.cameraPosition(with: geometry, focus: focus(MapProps.defaultFitPadding),
                                 azimuth: NSNumber(value: current.azimuth), tilt: NSNumber(value: current.tilt))
            : map.cameraPosition(with: geometry, focus: nil, azimuth: nil, tilt: nil)
        let zoom = min(max(fitted.zoom, current.zoom + 1), Self.maxFitZoom + 2)
        map.move(with: YMKCameraPosition(target: fitted.target, zoom: zoom, azimuth: current.azimuth, tilt: current.tilt),
                 animation: YMKAnimation(type: .smooth, duration: Self.fitSeconds), cameraCallback: nil)
    }

    // MARK: YMKMapSizeChangedListener, YMKMapCameraListener, YMKMapInputListener

    /// MapKit's window has its size: a fit asked before then runs now.
    func onMapWindowSizeChanged(with mapWindow: YMKMapWindow, newWidth: Int, newHeight: Int) {
        guard newWidth > 0, newHeight > 0 else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.pendingFit else { return }
            self.fit()
        }
    }

    func onCameraPositionChanged(with map: YMKMap, cameraPosition: YMKCameraPosition,
                                 cameraUpdateReason: YMKCameraUpdateReason, finished: Bool) {
        guard finished else { return }
        emit("cameraChange", ["lat": Self.round(cameraPosition.target.latitude, 6),
                                      "lng": Self.round(cameraPosition.target.longitude, 6),
                                      "zoom": Self.round(Double(cameraPosition.zoom), 3)])
    }

    func onMapTap(with map: YMKMap, point: YMKPoint) {
        emit("mapPress", ["lat": Self.round(point.latitude, 6), "lng": Self.round(point.longitude, 6)])
    }

    func onMapLongTap(with map: YMKMap, point: YMKPoint) {}

    /// Rounds half up, as Kotlin's `roundToLong` does, so both platforms send the same numbers.
    private static func round(_ v: Double, _ places: Double) -> Double {
        let k = pow(10, places)
        return (v * k + 0.5).rounded(.down) / k
    }
}
