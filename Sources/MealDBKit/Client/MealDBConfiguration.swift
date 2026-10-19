import Foundation

/// Settings of a ``MealDBClient``.
public struct MealDBConfiguration: Sendable {
    /// `https://www.themealdb.com/api/json/v1`, the folder that holds one folder per API key.
    public static let defaultBaseURL = URL(string: "https://www.themealdb.com/api/json/v1")!

    /// `"1"`, TheMealDB's free public test key. It is meant for development and educational use;
    /// apps released to an app store need a supporter key from themealdb.com.
    public static let testAPIKey = "1"

    /// Where requests go, without the key: the key is the next path component.
    /// Change it to point at a proxy or a local stub server.
    public var baseURL: URL
    /// The API key, sent as a path component (`/api/json/v1/<key>/search.php`).
    public var apiKey: String
    /// The session that performs requests. Give it a `URLProtocol` subclass to stub responses.
    public var session: URLSession
    /// Sent as `User-Agent`, so the API's maintainers can tell where traffic comes from.
    public var userAgent: String?
    /// The request timeout in seconds.
    public var timeout: TimeInterval

    public init(
        baseURL: URL = MealDBConfiguration.defaultBaseURL,
        apiKey: String = MealDBConfiguration.testAPIKey,
        session: URLSession = .shared,
        userAgent: String? = "MealDBKit (+https://github.com/halilozel1903/MealDBKit)",
        timeout: TimeInterval = 20
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
        self.userAgent = userAgent
        self.timeout = timeout
    }

    /// The base URL with the key: `https://www.themealdb.com/api/json/v1/1`.
    public var keyedBaseURL: URL {
        baseURL.appendingPathComponent(apiKey)
    }
}
