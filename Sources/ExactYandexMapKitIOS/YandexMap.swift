// exact-yandex-mapkit on iOS: the package's public API, which uses only UIKit and Foundation types, so code outside
// the dynamic library that holds MapKit never refers to a MapKit class (see Package.swift). apple/YandexMapModule.swift
// adapts it to Exact's package seam. As android/YandexMapModule.kt, MapKit's key is set here once per process.
import Foundation
import UIKit
import YandexMapsMobile

/// One `yandex-map`.
public final class YandexMap {
    private let map: OneYandexMap

    /// - Parameters:
    ///   - emit: told each event, by its declared name, with its one payload (`markerPress {id}`,
    ///     `cameraChange {lat, lng, zoom}`, `mapPress {lat, lng}`).
    ///   - log: a line for the app's log.
    public init(id: String, emit: @escaping (String, [String: Any]) -> Void, log: @escaping (String) -> Void) {
        map = OneYandexMap(id: id, emit: emit, log: log)
    }

    /// The view to place; it fills its box.
    public var view: UIView { map.view }

    /// Every prop, as Exact gives them: strings, replaced on each change.
    public func setProps(_ props: [String: String]) { map.setProps(props) }

    /// The app came back to the foreground.
    public func foreground() { map.foreground() }

    /// The node is gone.
    public func destroy() { map.destroy() }

    /// Gives MapKit its key, once per process and before the first map. An empty key still lets a map be made: Yandex
    /// then shows its own notice instead of tiles.
    public static func initialize(apiKey: String, log: (String) -> Void) {
        YandexKit.initialize(apiKey: apiKey, log: log)
    }
}

/// MapKit's process-wide state: the key, set once.
enum YandexKit {
    /// What MapKit is given when the app passes no key: the map is still made and Yandex shows its own notice.
    private static let noKey = "missing-yandex-mapkit-api-key"
    private static var key: String?

    static func initialize(apiKey: String, log: (String) -> Void) {
        let given = apiKey.isEmpty ? noKey : apiKey
        if let current = key {
            if current != given { log("yandex-map: MapKit already has a key for this process; a different apiKey takes effect after a restart") }
            return
        }
        if apiKey.isEmpty { log("yandex-map: no apiKey, so MapKit runs without a key and its tiles will not load; pass the app's YANDEX_MAPKIT_API_KEY") }
        YMKMapKit.setApiKey(given)
        YMKMapKit.sharedInstance().onStart()
        key = given
    }
}
