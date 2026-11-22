// exact-yandex-mapkit on iOS: marker icons (logo pins) from a marker's `icon`, decoded once per source. As
// android/IconLoader.kt.
//
// - `data:image/…;base64,…` decodes at once.
// - `https://…` downloads with URLSession (5 s timeout, at most 1 MB) and reports back on the main queue, so the
//   marker first draws without its icon and is redrawn with it.
// - Any other scheme, a failed download or bytes that are not an image leave the marker without an icon; the log says
//   why, once per source.
// Each image is scaled down to about the selected marker's size, and at most `maxIcons` are kept.
import UIKit

final class IconLoader {
    private static let maxIcons = 128
    private static let maxBytes = 1 << 20
    private static let timeout: TimeInterval = 5

    private let side: CGFloat
    private let log: (String) -> Void
    var loaded: (String) -> Void = { _ in }

    /// Decoded icons by source; a nil value is a source that failed, so it is not tried again.
    private var done: [String: UIImage?] = [:]
    private var order: [String] = []
    private var pending = Set<String>()
    private var closed = false
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = Self.timeout
        config.timeoutIntervalForResource = Self.timeout * 2
        return URLSession(configuration: config)
    }()

    init(side: CGFloat, log: @escaping (String) -> Void) {
        self.side = side
        self.log = log
    }

    /// The icon for `src` if it is ready; otherwise nil, and an `https` source starts loading.
    func get(_ src: String) -> UIImage? {
        if src.isEmpty || closed { return nil }
        if let hit = done[src] { return hit }
        if src.hasPrefix("data:") {
            let image = decodeData(src)
            finish(src, image)
            return image
        }
        guard src.hasPrefix("https://"), let url = URL(string: src) else {
            finish(src, nil)
            return nil
        }
        if pending.insert(src).inserted {
            session.dataTask(with: url) { [weak self] data, response, _ in
                let ok = (response as? HTTPURLResponse)?.statusCode == 200 && response?.url?.scheme == "https"
                let image = ok ? data.flatMap { $0.count <= Self.maxBytes ? self?.scaled($0) : nil } : nil
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.pending.remove(src)
                    if self.closed { return }
                    self.finish(src, image)
                    if image != nil { self.loaded(src) }
                }
            }.resume()
        }
        return nil
    }

    func close() {
        closed = true
        session.invalidateAndCancel()
        done = [:]
        order = []
        pending = []
    }

    private func finish(_ src: String, _ image: UIImage?) {
        if image == nil { log("yandex-map: marker icon \(src.prefix(60)) could not be loaded; the marker is drawn without it") }
        if done[src] == nil { order.append(src) }
        done[src] = .some(image)
        while order.count > Self.maxIcons { done[order.removeFirst()] = nil }
    }

    private func decodeData(_ src: String) -> UIImage? {
        guard let comma = src.firstIndex(of: ","), src[..<comma].hasSuffix(";base64"),
              let data = Data(base64Encoded: String(src[src.index(after: comma)...]), options: .ignoreUnknownCharacters) else { return nil }
        return scaled(data)
    }

    /// Decodes `data`, scaled down so its shorter side is at most `side` points (at the screen's scale).
    private func scaled(_ data: Data) -> UIImage? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let shorter = min(image.size.width, image.size.height)
        if shorter <= side { return image }
        let k = side / shorter
        let size = CGSize(width: image.size.width * k, height: image.size.height * k)
        return UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}
