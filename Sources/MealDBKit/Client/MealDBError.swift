import Foundation

/// Errors thrown by ``MealDBClient``.
///
/// An empty result is not an error: TheMealDB answers `{"meals": null}` when nothing matches,
/// and the client returns an empty array (or `nil` for a lookup by id) instead.
public enum MealDBError: Error, Equatable, Sendable, LocalizedError {
    /// An argument the API cannot answer, such as a first-letter search with two letters.
    case invalidArgument(String)
    /// The API answered `{"meals": null}` where a result is always expected (``MealDBClient/randomMeal()``).
    case emptyResponse(url: URL)
    /// An unsuccessful HTTP status.
    case http(statusCode: Int, url: URL)
    /// The response was not JSON of the expected shape.
    case decoding(type: String, description: String)
    /// The request could not be completed (offline, timed out, cancelled…).
    case transport(URLError)
    /// The response was not an HTTP response.
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case let .invalidArgument(message):
            return message
        case .emptyResponse:
            return "TheMealDB sent no meal."
        case let .http(statusCode, _):
            return "TheMealDB answered with HTTP status \(statusCode)."
        case let .decoding(type, _):
            return "TheMealDB sent data that could not be read as \(type)."
        case let .transport(error):
            return error.localizedDescription
        case .invalidResponse:
            return "TheMealDB sent an invalid response."
        }
    }
}
