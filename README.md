# exact-yandex-mapkit-ios

The Swift package behind the iOS side of `exact-yandex-mapkit`, a `yandex-map` view for
[Expo Exact](https://github.com/expo/exact).

You don't add this package yourself. The Exact package names it in its `apple/exact.json`
`swiftPackages`, and Exact resolves it when it builds the app.

## Why it is a separate package

Yandex ships MapKit for iOS as a static framework with every symbol hidden. Exact links all
of an app's Swift packages into one dynamic library, and code outside that library can't call
hidden symbols. So the code that talks to MapKit lives here, next to the binary, and exposes a
public `YandexMap` class that uses only UIKit and Foundation types.

## Contents

- `Package.swift`: a `binaryTarget` for Yandex's own `YandexMapsMobile 4.45.0-lite` archive
  (the one the CocoaPods pod downloads), checked by SHA-256, plus the system frameworks and
  libraries its podspec lists, and Metal and IOSurface.
- `Sources/ExactYandexMapKitIOS`: the map, markers and clusters, the route polyline, the camera
  and the events, ported file for file from the package's Android Kotlin.

No Yandex binaries are stored in this repository.

## Versions

Tags match `exact-yandex-mapkit` releases. Apps pin the tag's revision in `Package.resolved`,
so a tag is never moved. `0.2.0` is `ff058fd`.

## License

MIT. Yandex MapKit itself is under Yandex's own terms of use.
