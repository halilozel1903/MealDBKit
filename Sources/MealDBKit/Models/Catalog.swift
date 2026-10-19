import Foundation

/// A meal in a list, as `filter.php` sends it: an id, a name and a photo. Load the whole
/// recipe with ``MealDBClient/meal(id:)``.
public struct MealSummary: Identifiable, Hashable, Sendable, Codable {
    /// `idMeal`.
    public var id: String
    /// `strMeal`.
    public var name: String
    /// `strMealThumb`.
    public var thumbnailURL: URL?

    public init(id: String, name: String, thumbnailURL: URL?) {
        self.id = id
        self.name = name
        self.thumbnailURL = thumbnailURL
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        guard let id = container.text("idMeal") ?? (try? container.decode(Int.self, forKey: DynamicKey("idMeal"))).map({ String($0) }) else {
            throw DecodingError.keyNotFound(
                DynamicKey("idMeal"),
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "A meal needs an idMeal.")
            )
        }
        self.id = id
        name = container.text("strMeal") ?? ""
        thumbnailURL = container.url("strMealThumb")
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try container.encode(id, forKey: DynamicKey("idMeal"))
        try container.encode(name, forKey: DynamicKey("strMeal"))
        try container.encode(thumbnailURL?.absoluteString, forKey: DynamicKey("strMealThumb"))
    }

    /// The photo at `size`; `nil` when the meal has no photo.
    public func thumbnailURL(size: MealImageSize) -> URL? {
        thumbnailURL.map { MealDBImages.mealImageURL($0, size: size) }
    }
}

/// A category with its picture and description, as `categories.php` sends it.
public struct MealCategory: Identifiable, Hashable, Sendable, Codable {
    /// `idCategory`, such as `"1"`.
    public var id: String
    /// `strCategory`, such as `"Beef"`.
    public var name: String
    /// `strCategoryThumb`, a picture of the category.
    public var thumbnailURL: URL?
    /// `strCategoryDescription`.
    public var description: String

    public init(id: String, name: String, thumbnailURL: URL?, description: String) {
        self.id = id
        self.name = name
        self.thumbnailURL = thumbnailURL
        self.description = description
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        name = container.text("strCategory") ?? ""
        id = container.text("idCategory") ?? (try? container.decode(Int.self, forKey: DynamicKey("idCategory"))).map({ String($0) }) ?? name
        thumbnailURL = container.url("strCategoryThumb")
        description = container.text("strCategoryDescription") ?? ""
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try container.encode(id, forKey: DynamicKey("idCategory"))
        try container.encode(name, forKey: DynamicKey("strCategory"))
        try container.encode(thumbnailURL?.absoluteString, forKey: DynamicKey("strCategoryThumb"))
        try container.encode(description, forKey: DynamicKey("strCategoryDescription"))
    }

    /// The description without the "[1]" style reference marks some descriptions carry.
    public var cleanDescription: String {
        var text = description
        while let open = text.range(of: "["),
              let close = text.range(of: "]", range: open.upperBound..<text.endIndex),
              text[open.upperBound..<close.lowerBound].allSatisfy(\.isNumber) {
            text.removeSubrange(open.lowerBound..<close.upperBound)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// An ingredient from `list.php?i=list`, with its description and picture.
public struct Ingredient: Identifiable, Hashable, Sendable, Codable {
    /// `idIngredient`.
    public var id: String
    /// `strIngredient`, such as `"Chicken"`.
    public var name: String
    /// `strDescription`, when TheMealDB has one.
    public var description: String?
    /// `strType`, such as `"Meat"`, when TheMealDB has one.
    public var type: String?
    /// `strThumb`, when TheMealDB sends it; otherwise built from the name.
    public var thumbnailURL: URL?

    public init(id: String, name: String, description: String? = nil, type: String? = nil, thumbnailURL: URL? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.thumbnailURL = thumbnailURL
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        name = container.text("strIngredient") ?? ""
        id = container.text("idIngredient") ?? (try? container.decode(Int.self, forKey: DynamicKey("idIngredient"))).map({ String($0) }) ?? name
        description = container.text("strDescription")
        type = container.text("strType")
        thumbnailURL = container.url("strThumb")
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try container.encode(id, forKey: DynamicKey("idIngredient"))
        try container.encode(name, forKey: DynamicKey("strIngredient"))
        try container.encode(description, forKey: DynamicKey("strDescription"))
        try container.encode(type, forKey: DynamicKey("strType"))
        try container.encode(thumbnailURL?.absoluteString, forKey: DynamicKey("strThumb"))
    }

    /// The ingredient's picture at `size`.
    public func imageURL(size: IngredientImageSize = .small) -> URL {
        MealDBImages.ingredientImageURL(name: name, size: size)
    }
}

/// A cuisine from `list.php?a=list`, such as `"Italian"`.
public struct MealArea: Identifiable, Hashable, Sendable, Codable, Comparable {
    /// `strArea`.
    public var name: String

    public var id: String { name }

    public init(name: String) {
        self.name = name
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        name = container.text("strArea") ?? ""
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try container.encode(name, forKey: DynamicKey("strArea"))
    }

    public static func < (lhs: MealArea, rhs: MealArea) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    /// The ISO 3166 code of the country the cuisine is named after, for the areas TheMealDB
    /// lists; `nil` for `"Unknown"` and names this table does not know.
    public var countryCode: String? {
        MealArea.countryCodes[name.lowercased()]
    }

    /// The flag of ``countryCode``, such as "🇮🇹" for Italian.
    public var flag: String? {
        guard let code = countryCode else { return nil }
        let scalars = code.uppercased().unicodeScalars.compactMap { UnicodeScalar(127_397 + $0.value) }
        var flag = ""
        flag.unicodeScalars.append(contentsOf: scalars)
        return flag
    }

    static let countryCodes: [String: String] = [
        "algerian": "dz", "american": "us", "argentinian": "ar", "australian": "au",
        "british": "gb", "canadian": "ca", "chinese": "cn", "croatian": "hr",
        "dutch": "nl", "egyptian": "eg", "filipino": "ph", "french": "fr",
        "greek": "gr", "indian": "in", "irish": "ie", "italian": "it",
        "jamaican": "jm", "japanese": "jp", "kenyan": "ke", "malaysian": "my",
        "mexican": "mx", "moroccan": "ma", "norwegian": "no", "polish": "pl",
        "portuguese": "pt", "russian": "ru", "saudi arabian": "sa", "slovakian": "sk",
        "spanish": "es", "syrian": "sy", "thai": "th", "tunisian": "tn",
        "turkish": "tr", "ukrainian": "ua", "uruguayan": "uy", "venezulan": "ve",
        "venezuelan": "ve", "vietnamese": "vn",
    ]
}

/// An entry of `list.php?c=list`: a category name only.
struct CategoryName: Decodable {
    let name: String

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        name = container.text("strCategory") ?? ""
    }
}
