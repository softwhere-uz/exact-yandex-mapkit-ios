// exact-yandex-mapkit on iOS: the text badges of one map (`badges`), in their own collection above the markers and below
// the selected one. As android/BadgeLayer.kt: badges are never clustered, and a tap on one reports its id and is
// consumed.
import UIKit
import YandexMapsMobile

final class BadgeLayer: NSObject, YMKMapObjectTapListener {
    private static let badgeZ: Float = 50

    private let collection: YMKMapObjectCollection
    private let icons: MarkerIcons
    private let onBadge: (String) -> Void

    init(root: YMKMapObjectCollection, icons: MarkerIcons, onBadge: @escaping (String) -> Void) {
        collection = root.add()
        self.icons = icons
        self.onBadge = onBadge
        super.init()
        collection.zIndex = Self.badgeZ
        collection.addTapListener(with: self)
    }

    /// Redraws every badge: called only when `badges` or night mode changed.
    func set(_ badges: [BadgeSpec], night: Bool) {
        collection.clear()
        let style = YMKIconStyle()
        style.anchor = NSValue(cgPoint: CGPoint(x: 0.5, y: 1))
        style.zIndex = NSNumber(value: Self.badgeZ)
        for badge in badges {
            let placemark = collection.addPlacemark()
            placemark.geometry = YMKPoint(latitude: badge.lat, longitude: badge.lng)
            placemark.setIconWith(icons.badge(text: badge.text, tone: badge.tone, night: night), style: style)
            placemark.userData = badge.id
        }
    }

    func clear() { collection.clear() }

    func onMapObjectTap(with mapObject: YMKMapObject, point: YMKPoint) -> Bool {
        guard let id = mapObject.userData as? String else { return false }
        onBadge(id)
        return true
    }
}
