// swift-tools-version:5.9
// exact-yandex-mapkit's iOS map, as a Swift package: the `yandex-map` view's MapKit code, and YandexMapsMobile
// (MapKit 4.45.0, lite flavour) under it. Expo Exact takes native iOS libraries as Swift packages, not CocoaPods.
//
// Why the map code lives here and not in the Exact package's own Swift (apple/*.swift): Yandex's static framework
// marks its symbols private external (hidden). Exact links every Swift package an app uses into one dynamic library,
// and a dynamic library cannot export hidden symbols, so Swift outside that library cannot use MapKit's classes. The
// code that uses them is therefore compiled into the same library, and it offers a small public API (`YandexMap`)
// that uses only UIKit and Foundation types. apple/YandexMapModule.swift adapts that API to Exact.
//
// The binary is Yandex's own archive, the one the CocoaPods pod `YandexMapsMobile 4.45.0-lite` downloads. SwiftPM
// fetches it from Yandex and checks it against `checksum` (the archive's SHA-256). Nothing of Yandex's is copied
// into this package. The archive's xcframework is named `YandexMapsMobileLite`, so the binary target has that name;
// the module inside it is still `YandexMapsMobile`.
import PackageDescription

let package = Package(
    name: "ExactYandexMapKitIOS",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "ExactYandexMapKitIOS", targets: ["ExactYandexMapKitIOS"]),
    ],
    targets: [
        .binaryTarget(
            name: "YandexMapsMobileLite",
            url: "https://maps-ios-pods-public.s3.yandex.net/YandexMapsMobile-4.45.0-lite.framework.zip",
            checksum: "0b0478a73284d210904bdb3f32c283d7c0de8ebd745d9f396b51ddca2ae74c8e"
        ),
        .target(
            name: "ExactYandexMapKitIOS",
            dependencies: ["YandexMapsMobileLite"],
            path: "Sources/ExactYandexMapKitIOS",
            // MapKit's resource bundle, which the pod copies into the app; MapKitResources.swift hands it to MapKit.
            resources: [.copy("Resources/Contents.bundle")],
            // What the podspec lists under `frameworks` and `libraries`, which a binary target cannot carry.
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedLibrary("resolv"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("Foundation"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("UIKit"),
                .linkedFramework("OpenGLES"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("Security"),
                .linkedFramework("CoreTelephony"),
                .linkedFramework("CoreMotion"),
                .linkedFramework("DeviceCheck"),
                .linkedFramework("NetworkExtension"),
                // Not in the podspec, which links only what MapKit's used objects need. Exact links the whole archive
                // into one dynamic library (-force_load), which also takes MapKit's Metal renderer (MoltenVK).
                .linkedFramework("Metal"),
                .linkedFramework("IOSurface"),
            ]
        ),
    ]
)
