// MapKit's resource bundle. YandexMapsMobile asks the Objective-C runtime for a class named
// `YandexMapsMobileSwiftResources` and takes its `+mapkitResourcesBundle`, which is how Yandex's own Swift package
// (github.com/yandex/mapkit-ios) hands MapKit its bundle. The CocoaPods pod copies YandexMapsMobile.bundle into the
// app instead. A binary target cannot carry resources, so this package ships the bundle (Resources/Contents.bundle,
// only an Info.plist for the lite flavour) and offers the class, as Yandex's package does.
//
// The bundle is looked up by hand, not through `Bundle.module`, because `Bundle.module` stops the app when it cannot
// find the bundle. Exact places a Swift package's resource bundle at the top of the app.
import Foundation

@objc(YandexMapsMobileSwiftResources)
public final class YandexMapsMobileSwiftResources: NSObject {
    private static let packageBundle = "ExactYandexMapKitIOS_ExactYandexMapKitIOS.bundle"

    @objc public static func mapkitResourcesBundle() -> Bundle? {
        let roots = [Bundle.main.bundleURL, Bundle.main.resourceURL, Bundle(for: YandexMapsMobileSwiftResources.self).bundleURL]
        for root in roots.compactMap({ $0 }) {
            let contents = root.appendingPathComponent(packageBundle, isDirectory: true)
                .appendingPathComponent("Contents.bundle", isDirectory: true)
            if let bundle = Bundle(url: contents) { return bundle }
        }
        return nil
    }
}
