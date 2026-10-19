import SwiftUI
import MealDBKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Loads the bytes of an image URL. The views in this module load photos through the loader in
/// the environment, so you can swap in your own cache or, in previews and tests, bundled artwork.
///
/// ```swift
/// ContentView()
///     .mealDBImageLoader(MealDBImageLoader { url in
///         try await MyImageCache.shared.data(for: url)
///     })
/// ```
public struct MealDBImageLoader: Sendable {
    private let load: @Sendable (URL) async throws -> Data

    public init(_ load: @escaping @Sendable (URL) async throws -> Data) {
        self.load = load
    }

    public func data(for url: URL) async throws -> Data {
        try await load(url)
    }

    /// Loads over `URLSession.shared` (or from disk for file URLs), keeping recent images in
    /// memory. Responses other than 2xx throw `URLError(.badServerResponse)`.
    public static let urlSession = MealDBImageLoader { url in
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        if let cached = await ImageDataCache.shared.data(for: url) {
            return cached
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        await ImageDataCache.shared.insert(data, for: url)
        return data
    }
}

/// Recently loaded image bytes, so scrolling back doesn't hit the network again.
actor ImageDataCache {
    static let shared = ImageDataCache()

    private var entries: [URL: Data] = [:]
    private var order: [URL] = []
    private let limit = 300

    func data(for url: URL) -> Data? {
        entries[url]
    }

    func insert(_ data: Data, for url: URL) {
        if entries[url] == nil {
            order.append(url)
        }
        entries[url] = data
        while order.count > limit {
            entries[order.removeFirst()] = nil
        }
    }
}

/// Decoded images, so a photo that scrolls back into view appears at once.
@MainActor
final class DecodedImageCache {
    static let shared = DecodedImageCache()

    private var images: [URL: Image] = [:]
    private var order: [URL] = []
    private let limit = 300

    func image(for url: URL) -> Image? {
        images[url]
    }

    func insert(_ image: Image, for url: URL) {
        if images[url] == nil {
            order.append(url)
        }
        images[url] = image
        while order.count > limit {
            images[order.removeFirst()] = nil
        }
    }

    static func decode(_ data: Data) -> Image? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }
}

private struct MealDBImageLoaderKey: EnvironmentKey {
    static let defaultValue: MealDBImageLoader = .urlSession
}

extension EnvironmentValues {
    /// The loader ``MealDBImage`` uses. Defaults to ``MealDBImageLoader/urlSession``.
    public var mealDBImageLoader: MealDBImageLoader {
        get { self[MealDBImageLoaderKey.self] }
        set { self[MealDBImageLoaderKey.self] = newValue }
    }
}

extension View {
    /// Loads every photo below this view with `loader`.
    public func mealDBImageLoader(_ loader: MealDBImageLoader) -> some View {
        environment(\.mealDBImageLoader, loader)
    }
}

/// An image from a URL that fills the space it is given, with a placeholder while it loads or
/// when there is no image.
///
/// Give it a frame or an aspect ratio; the image is scaled to fill and clipped.
public struct MealDBImage<Placeholder: View>: View {
    private let url: URL?
    private let contentMode: ContentMode
    private let placeholder: Placeholder

    @Environment(\.mealDBImageLoader) private var loader
    @State private var loaded: LoadedImage?

    public init(url: URL?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    public var body: some View {
        Color.clear
            .overlay {
                if let image = currentImage {
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .transition(.opacity)
                } else {
                    placeholder
                }
            }
            .clipped()
            .task(id: url) {
                await load()
            }
    }

    private var currentImage: Image? {
        guard let url else { return nil }
        if let loaded, loaded.url == url {
            return loaded.image
        }
        return DecodedImageCache.shared.image(for: url)
    }

    private func load() async {
        guard let url, DecodedImageCache.shared.image(for: url) == nil else { return }
        guard let data = try? await loader.data(for: url), !Task.isCancelled else { return }
        guard let image = DecodedImageCache.decode(data) else { return }
        DecodedImageCache.shared.insert(image, for: url)
        withAnimation(.easeOut(duration: 0.2)) {
            loaded = LoadedImage(url: url, image: image)
        }
    }
}

private struct LoadedImage {
    let url: URL
    let image: Image
}

extension MealDBImage where Placeholder == FoodPlaceholder {
    /// An image with a generated placeholder: a warm gradient with a fork and knife.
    public init(url: URL?, contentMode: ContentMode = .fill) {
        self.init(url: url, contentMode: contentMode) {
            FoodPlaceholder()
        }
    }
}

/// A warm gradient with a fork and knife, shown while a photo loads or when there is none.
public struct FoodPlaceholder: View {
    public init() {}

    public var body: some View {
        LinearGradient(
            colors: [Color(red: 0.98, green: 0.88, blue: 0.76), Color(red: 0.94, green: 0.74, blue: 0.58)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            GeometryReader { proxy in
                Image(systemName: "fork.knife")
                    .font(.system(size: max(12, min(proxy.size.width, proxy.size.height) * 0.3), weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .accessibilityHidden(true)
    }
}
