import Foundation

/// Sizes of a meal photo. TheMealDB serves smaller copies when a size is added to the photo's
/// URL: `…/ustsqw1468250014.jpg/preview`.
public enum MealImageSize: String, CaseIterable, Sendable {
    /// The photo as uploaded (usually 700 × 700).
    case original
    /// `/preview`, a 250 × 250 thumbnail, made for lists and grids.
    case preview
    /// `/small`.
    case small
    /// `/medium`.
    case medium
    /// `/large`.
    case large

    /// The path component added to the photo URL; `nil` for the original.
    public var pathComponent: String? {
        self == .original ? nil : rawValue
    }
}

/// Sizes of an ingredient picture: `…/ingredients/lime.png`, `lime-small.png`,
/// `lime-medium.png` and `lime-large.png`.
public enum IngredientImageSize: String, CaseIterable, Sendable {
    /// The picture as uploaded.
    case original
    /// `-small`, about 100 × 100.
    case small
    /// `-medium`, about 250 × 250.
    case medium
    /// `-large`, about 500 × 500.
    case large

    /// The suffix added before `.png`.
    public var suffix: String {
        self == .original ? "" : "-" + rawValue
    }
}

/// URL helpers for TheMealDB's pictures.
public enum MealDBImages {
    /// `https://www.themealdb.com/images`.
    public static let baseURL = URL(string: "https://www.themealdb.com/images")!

    /// A meal photo at `size`: the URL with `/preview`, `/small`, `/medium` or `/large` added.
    /// A URL that already ends in one of them is resized, not extended.
    public static func mealImageURL(_ url: URL, size: MealImageSize) -> URL {
        var text = url.absoluteString
        for component in MealImageSize.allCases.compactMap(\.pathComponent) where text.hasSuffix("/" + component) {
            text.removeLast(component.count + 1)
            break
        }
        guard let component = size.pathComponent else { return URL(string: text) ?? url }
        return URL(string: text + "/" + component) ?? url
    }

    /// The picture of an ingredient by name: `"Chicken Breast"` at `.small` is
    /// `https://www.themealdb.com/images/ingredients/chicken%20breast-small.png`. Names are
    /// lowercased, as in TheMealDB's documentation.
    public static func ingredientImageURL(name: String, size: IngredientImageSize = .small, baseURL: URL = MealDBImages.baseURL) -> URL {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#")
        let file = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() + size.suffix + ".png"
        let encoded = file.addingPercentEncoding(withAllowedCharacters: allowed) ?? file
        return URL(string: baseURL.absoluteString + "/ingredients/" + encoded)!
    }

    /// The video id in a YouTube link: `watch?v=ID`, `youtu.be/ID`, `embed/ID` or `shorts/ID`.
    public static func youtubeVideoID(in url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased() else { return nil }
        let id: String?
        if host.hasSuffix("youtu.be") {
            id = url.pathComponents.dropFirst().first
        } else if host.hasSuffix("youtube.com") || host.hasSuffix("youtube-nocookie.com") {
            if let value = components.queryItems?.first(where: { $0.name == "v" })?.value {
                id = value
            } else {
                let parts = url.pathComponents
                if let index = parts.firstIndex(where: { $0 == "embed" || $0 == "shorts" || $0 == "v" }), parts.indices.contains(index + 1) {
                    id = parts[index + 1]
                } else {
                    id = nil
                }
            }
        } else {
            id = nil
        }
        guard let id, !id.isEmpty else { return nil }
        return id
    }

    /// The thumbnail YouTube shows for a video: `https://img.youtube.com/vi/<id>/hqdefault.jpg`.
    public static func youtubeThumbnailURL(videoID: String) -> URL {
        URL(string: "https://img.youtube.com/vi/" + videoID + "/hqdefault.jpg")!
    }
}
