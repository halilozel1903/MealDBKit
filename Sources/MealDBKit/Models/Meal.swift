import Foundation

/// A full recipe, as `search.php`, `lookup.php` and `random.php` send it.
///
/// TheMealDB sends the ingredients as twenty pairs of flat fields, `strIngredient1` …
/// `strIngredient20` and `strMeasure1` … `strMeasure20`, padded with `""`, `" "` or `null`.
/// `Meal` reads them into ``ingredients``, a typed list with only the filled positions, and
/// writes them back in the same flat shape when encoded.
public struct Meal: Identifiable, Hashable, Sendable, Codable {
    /// `idMeal`, such as `"52771"`.
    public var id: String
    /// `strMeal`, such as `"Spicy Arrabiata Penne"`.
    public var name: String
    /// `strMealAlternate`, another name for the dish.
    public var alternateName: String?
    /// `strCategory`, such as `"Vegetarian"`.
    public var category: String?
    /// `strArea`, the cuisine, such as `"Italian"`.
    public var area: String?
    /// `strInstructions`, as sent. ``instructionSteps`` splits it into steps.
    public var instructions: String
    /// `strMealThumb`, the photo. ``thumbnailURL(size:)`` gives the smaller sizes.
    public var thumbnailURL: URL?
    /// `strTags` split at commas: `"Pasta,Curry"` is `["Pasta", "Curry"]`.
    public var tags: [String]
    /// `strYoutube`, a video of the recipe.
    public var youtubeURL: URL?
    /// `strSource`, the page the recipe comes from.
    public var sourceURL: URL?
    /// `strImageSource`, where the photo comes from.
    public var imageSourceURL: URL?
    /// `strCreativeCommonsConfirmed`, whether the photo is confirmed to be Creative Commons.
    public var creativeCommonsConfirmed: Bool?
    /// `dateModified`, as sent.
    public var dateModified: String?
    /// The filled `strIngredientN` and `strMeasureN` pairs, in order.
    public var ingredients: [MealIngredient]

    public init(
        id: String,
        name: String,
        alternateName: String? = nil,
        category: String? = nil,
        area: String? = nil,
        instructions: String = "",
        thumbnailURL: URL? = nil,
        tags: [String] = [],
        youtubeURL: URL? = nil,
        sourceURL: URL? = nil,
        imageSourceURL: URL? = nil,
        creativeCommonsConfirmed: Bool? = nil,
        dateModified: String? = nil,
        ingredients: [MealIngredient] = []
    ) {
        self.id = id
        self.name = name
        self.alternateName = alternateName
        self.category = category
        self.area = area
        self.instructions = instructions
        self.thumbnailURL = thumbnailURL
        self.tags = tags
        self.youtubeURL = youtubeURL
        self.sourceURL = sourceURL
        self.imageSourceURL = imageSourceURL
        self.creativeCommonsConfirmed = creativeCommonsConfirmed
        self.dateModified = dateModified
        self.ingredients = ingredients
    }

    /// The most numbered ingredient fields read; TheMealDB sends 20.
    static let maxIngredientFields = 50

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        let numericID = (try? container.decode(Int.self, forKey: DynamicKey("idMeal"))).map(String.init)
        guard let id = container.text("idMeal") ?? numericID else {
            throw DecodingError.keyNotFound(
                DynamicKey("idMeal"),
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "A meal needs an idMeal.")
            )
        }
        self.id = id
        name = container.text("strMeal") ?? ""
        alternateName = container.text("strMealAlternate")
        category = container.text("strCategory")
        area = container.text("strArea")
        instructions = container.text("strInstructions") ?? ""
        thumbnailURL = container.url("strMealThumb")
        tags = Meal.tags(from: container.text("strTags"))
        youtubeURL = container.url("strYoutube")
        sourceURL = container.url("strSource")
        imageSourceURL = container.url("strImageSource")
        creativeCommonsConfirmed = container.text("strCreativeCommonsConfirmed").flatMap(Meal.flag)
        dateModified = container.text("dateModified")

        var ingredients: [MealIngredient] = []
        var position = 1
        while position <= Meal.maxIngredientFields,
              container.has("strIngredient" + String(position)) || container.has("strMeasure" + String(position)) {
            if let name = container.text("strIngredient" + String(position)) {
                let measure = container.text("strMeasure" + String(position)) ?? ""
                ingredients.append(MealIngredient(position: position, name: name, measure: measure))
            }
            position += 1
        }
        self.ingredients = ingredients
    }

    /// Writes the meal in TheMealDB's own flat shape, with at least 20 ingredient fields.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try container.encode(id, forKey: DynamicKey("idMeal"))
        try container.encode(name, forKey: DynamicKey("strMeal"))
        try container.encode(alternateName, forKey: DynamicKey("strMealAlternate"))
        try container.encode(category, forKey: DynamicKey("strCategory"))
        try container.encode(area, forKey: DynamicKey("strArea"))
        try container.encode(instructions, forKey: DynamicKey("strInstructions"))
        try container.encode(thumbnailURL?.absoluteString, forKey: DynamicKey("strMealThumb"))
        try container.encode(tags.isEmpty ? nil : tags.joined(separator: ","), forKey: DynamicKey("strTags"))
        try container.encode(youtubeURL?.absoluteString, forKey: DynamicKey("strYoutube"))
        try container.encode(sourceURL?.absoluteString, forKey: DynamicKey("strSource"))
        try container.encode(imageSourceURL?.absoluteString, forKey: DynamicKey("strImageSource"))
        try container.encode(creativeCommonsConfirmed.map { $0 ? "Yes" : "No" }, forKey: DynamicKey("strCreativeCommonsConfirmed"))
        try container.encode(dateModified, forKey: DynamicKey("dateModified"))
        let byPosition = Dictionary(ingredients.map { ($0.position, $0) }, uniquingKeysWith: { first, _ in first })
        let last = max(20, ingredients.map(\.position).max() ?? 0)
        for position in 1...last {
            let ingredient = byPosition[position]
            try container.encode(ingredient?.name, forKey: DynamicKey("strIngredient" + String(position)))
            try container.encode(ingredient?.measure, forKey: DynamicKey("strMeasure" + String(position)))
        }
    }

    /// `"Pasta,Curry"` → `["Pasta", "Curry"]`; blank parts are dropped.
    static func tags(from text: String?) -> [String] {
        guard let text else { return [] }
        return text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// `"Yes"` / `"No"` (and `true` / `false`, `1` / `0`) as a Bool.
    static func flag(_ text: String) -> Bool? {
        switch text.lowercased() {
        case "yes", "true", "1": return true
        case "no", "false", "0": return false
        default: return nil
        }
    }
}

// MARK: - Derived values

extension Meal {
    /// The instructions as numbered steps: one per line, without blank lines, `STEP 1` headings
    /// or `1.` prefixes that some recipes carry.
    public var instructionSteps: [String] {
        MealInstructions.steps(from: instructions)
    }

    /// The photo at `size`; `nil` when the meal has no photo.
    public func thumbnailURL(size: MealImageSize) -> URL? {
        thumbnailURL.map { MealDBImages.mealImageURL($0, size: size) }
    }

    /// The id of the YouTube video, such as `"1IszT_guI08"`.
    public var youtubeVideoID: String? {
        youtubeURL.flatMap(MealDBImages.youtubeVideoID(in:))
    }

    /// The meal as the short form that `filter.php` sends.
    public var summary: MealSummary {
        MealSummary(id: id, name: name, thumbnailURL: thumbnailURL)
    }

    /// The cuisine as a ``MealArea``.
    public var mealArea: MealArea? {
        area.map(MealArea.init(name:))
    }
}

/// One ingredient of a ``Meal``: a filled `strIngredientN` with its `strMeasureN`.
public struct MealIngredient: Identifiable, Hashable, Sendable, Codable {
    /// N, the position of the fields (1 to 20).
    public var position: Int
    /// `strIngredientN`, such as `"penne rigate"`.
    public var name: String
    /// `strMeasureN`, such as `"1 pound"`; `""` when the recipe gives none.
    public var measure: String

    public var id: Int { position }

    public init(position: Int, name: String, measure: String) {
        self.position = position
        self.name = name
        self.measure = measure
    }

    /// The ingredient's picture on TheMealDB at `size`.
    public func imageURL(size: IngredientImageSize = .small) -> URL {
        MealDBImages.ingredientImageURL(name: name, size: size)
    }
}

/// Splits recipe instructions into steps.
public enum MealInstructions {
    /// One step per non-blank line. Lines that are only a heading such as `STEP 1`, `Step 2:` or
    /// `3.` are dropped, and leading `STEP 4 ` or `5. ` markers are removed, so steps can be
    /// numbered by the view.
    public static func steps(from text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let step = stripMarker(line.trimmingCharacters(in: .whitespacesAndNewlines))
                return step.isEmpty ? nil : step
            }
    }

    /// `"STEP 2 - Fry the onions"` → `"Fry the onions"`, `"3. Serve"` → `"Serve"`,
    /// `"STEP 1"` → `""`; other lines unchanged.
    static func stripMarker(_ line: String) -> String {
        var rest = Substring(line)
        let separators: Set<Character> = [".", ")", ":", "-", "–", "—"]
        if rest.lowercased().hasPrefix("step") {
            let afterWord = rest.dropFirst(4).drop(while: { $0 == " " })
            let digits = afterWord.prefix(while: \.isNumber)
            guard !digits.isEmpty else { return line }
            rest = afterWord.dropFirst(digits.count)
            rest = rest.drop(while: { $0 == " " || separators.contains($0) })
            return String(rest).trimmingCharacters(in: .whitespaces)
        }
        let digits = rest.prefix(while: \.isNumber)
        guard !digits.isEmpty, digits.count <= 2 else { return line }
        let after = rest.dropFirst(digits.count)
        if after.isEmpty {
            return ""
        }
        if let first = after.first, first == "." || first == ")" {
            let text = after.dropFirst()
            // "1.5 kg" is a quantity, not a step number.
            if let next = text.first, next.isNumber { return line }
            return String(text).trimmingCharacters(in: .whitespaces)
        }
        return line
    }
}
