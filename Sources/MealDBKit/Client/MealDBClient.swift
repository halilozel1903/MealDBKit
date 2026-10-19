import Foundation

/// A client for [TheMealDB](https://www.themealdb.com/api.php), the open recipe database.
///
/// Every endpoint of the free API is an `async throws` method that returns typed models. TheMealDB
/// answers `{"meals": null}` when nothing matches; the client returns an empty array, or `nil`
/// for a lookup by id, so "no results" is never an error.
///
/// ```swift
/// let api = MealDBClient()                                   // the free test key "1"
/// let meals = try await api.searchMeals(name: "Arrabiata")   // [Meal]
/// let penne = try await api.meal(id: "52771")                // Meal?
/// penne?.ingredients.first                                   // penne rigate, 1 pound
/// let seafood = try await api.meals(inCategory: "Seafood")   // [MealSummary]
/// ```
///
/// One client can be shared by the whole app; it is `Sendable` and keeps no per-request state.
public final class MealDBClient: Sendable {
    /// A client with the default configuration and the free test key.
    public static let shared = MealDBClient()

    public let configuration: MealDBConfiguration

    public init(configuration: MealDBConfiguration = MealDBConfiguration()) {
        self.configuration = configuration
    }

    /// A client with your API key, with the default settings otherwise.
    public convenience init(apiKey: String) {
        self.init(configuration: MealDBConfiguration(apiKey: apiKey))
    }

    /// A client using `session`, with the default settings otherwise.
    public convenience init(session: URLSession) {
        self.init(configuration: MealDBConfiguration(session: session))
    }

    // MARK: - Meals

    /// Meals whose name contains `name` (`search.php?s=`), with their full recipes.
    /// Returns an empty array when nothing matches.
    public func searchMeals(name: String) async throws -> [Meal] {
        try await list("search.php", query: ["s": name.trimmingCharacters(in: .whitespacesAndNewlines)])
    }

    /// Meals whose name starts with `letter` (`search.php?f=`), with their full recipes.
    /// Throws ``MealDBError/invalidArgument(_:)`` unless `letter` is one letter or digit.
    public func meals(startingWith letter: Character) async throws -> [Meal] {
        guard letter.isLetter || letter.isNumber, letter.isASCII else {
            throw MealDBError.invalidArgument("A first-letter search takes one letter from A to Z, not \"\(letter)\".")
        }
        return try await list("search.php", query: ["f": String(letter).lowercased()])
    }

    /// The meal with `id` (`lookup.php?i=`), or `nil` when there is none.
    public func meal(id: String) async throws -> Meal? {
        let id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }
        let meals: [Meal] = try await list("lookup.php", query: ["i": id])
        return meals.first
    }

    /// The meal with `id` (`lookup.php?i=`), or `nil` when there is none.
    public func meal(id: Int) async throws -> Meal? {
        try await meal(id: String(id))
    }

    /// The full recipe of a meal from a list.
    public func meal(for summary: MealSummary) async throws -> Meal? {
        try await meal(id: summary.id)
    }

    /// Several meals by id, loaded in parallel and returned in the order of `ids`. Ids without a
    /// meal and repeated ids are left out.
    public func meals(ids: [String]) async throws -> [Meal] {
        var seen = Set<String>()
        let unique = ids.filter { !$0.isEmpty && seen.insert($0).inserted }
        let found = try await withThrowingTaskGroup(of: (Int, Meal?).self) { group in
            for (index, id) in unique.enumerated() {
                group.addTask {
                    let meal = try await self.meal(id: id)
                    return (index, meal)
                }
            }
            var results: [Int: Meal] = [:]
            for try await (index, meal) in group {
                results[index] = meal
            }
            return results
        }
        return unique.indices.compactMap { found[$0] }
    }

    /// A random meal (`random.php`).
    public func randomMeal() async throws -> Meal {
        let urlRequest = try self.request("random.php")
        let meals: [Meal] = try await decodeList(from: data(for: urlRequest))
        guard let meal = meals.first else {
            throw MealDBError.emptyResponse(url: urlRequest.url ?? configuration.keyedBaseURL)
        }
        return meal
    }

    // MARK: - Lists

    /// Every category with its picture and description (`categories.php`).
    public func categories() async throws -> [MealCategory] {
        try await list("categories.php", key: "categories")
    }

    /// The names of every category (`list.php?c=list`).
    public func categoryNames() async throws -> [String] {
        let names: [CategoryName] = try await list("list.php", query: ["c": "list"])
        return names.map(\.name).filter { !$0.isEmpty }
    }

    /// Every cuisine (`list.php?a=list`).
    public func areas() async throws -> [MealArea] {
        let areas: [MealArea] = try await list("list.php", query: ["a": "list"])
        return areas.filter { !$0.name.isEmpty }
    }

    /// Every ingredient with its description (`list.php?i=list`).
    public func ingredients() async throws -> [Ingredient] {
        let ingredients: [Ingredient] = try await list("list.php", query: ["i": "list"])
        return ingredients.filter { !$0.name.isEmpty }
    }

    // MARK: - Filters

    /// The meals of a category, such as `"Seafood"` (`filter.php?c=`).
    public func meals(inCategory category: String) async throws -> [MealSummary] {
        try await list("filter.php", query: ["c": category.trimmingCharacters(in: .whitespacesAndNewlines)])
    }

    /// The meals of a category.
    public func meals(in category: MealCategory) async throws -> [MealSummary] {
        try await meals(inCategory: category.name)
    }

    /// The meals of a cuisine, such as `"Canadian"` (`filter.php?a=`).
    public func meals(fromArea area: String) async throws -> [MealSummary] {
        try await list("filter.php", query: ["a": area.trimmingCharacters(in: .whitespacesAndNewlines)])
    }

    /// The meals of a cuisine.
    public func meals(from area: MealArea) async throws -> [MealSummary] {
        try await meals(fromArea: area.name)
    }

    /// The meals with a main ingredient (`filter.php?i=`). TheMealDB writes multi-word
    /// ingredients with underscores; `"chicken breast"` is sent as `chicken_breast`.
    public func meals(withIngredient ingredient: String) async throws -> [MealSummary] {
        try await list("filter.php", query: ["i": MealDBClient.ingredientQuery(ingredient)])
    }

    /// `"Chicken Breast "` → `"chicken_breast"`.
    static func ingredientQuery(_ ingredient: String) -> String {
        ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: "_")
    }

    // MARK: - Requests

    /// Builds the request for an endpoint such as `search.php`. Exposed for tests and debugging.
    public func request(_ endpoint: String, query: KeyValuePairs<String, String> = [:]) throws -> URLRequest {
        let url = configuration.keyedBaseURL.appendingPathComponent(endpoint)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw MealDBError.transport(URLError(.badURL))
        }
        if !query.isEmpty {
            // Encoded by hand: URLComponents leaves "+" (read as a space by servers) and, on some
            // platforms, "&" and "=" in values as they are.
            components.percentEncodedQuery = query
                .map { MealDBClient.encodeQueryPart($0.key) + "=" + MealDBClient.encodeQueryPart($0.value) }
                .joined(separator: "&")
        }
        guard let finalURL = components.url else {
            throw MealDBError.transport(URLError(.badURL))
        }
        var request = URLRequest(url: finalURL, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let userAgent = configuration.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        return request
    }

    static func encodeQueryPart(_ text: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#/")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    /// Fetches the list in an endpoint's `meals` (or `key`) field.
    func list<Item: Decodable>(_ endpoint: String, query: KeyValuePairs<String, String> = [:], key: String = "meals") async throws -> [Item] {
        try await decodeList(from: data(for: request(endpoint, query: query)), key: key)
    }

    func decodeList<Item: Decodable>(from data: Data, key: String = "meals") throws -> [Item] {
        // An empty or blank body is an empty list.
        if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) {
            return []
        }
        let decoder = JSONDecoder()
        decoder.userInfo[Envelope<Item>.keyInfo] = key
        do {
            return try decoder.decode(Envelope<Item>.self, from: data).items
        } catch {
            throw MealDBError.decoding(type: "[" + String(describing: Item.self) + "]", description: String(describing: error))
        }
    }

    /// Performs a request and returns the body of a successful response.
    func data(for request: URLRequest) async throws -> Data {
        let result: (Data, URLResponse)
        do {
            result = try await configuration.session.data(for: request)
        } catch let error as URLError {
            throw MealDBError.transport(error)
        }
        guard let http = result.1 as? HTTPURLResponse else {
            throw MealDBError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MealDBError.http(statusCode: http.statusCode, url: request.url ?? configuration.keyedBaseURL)
        }
        return result.0
    }
}
