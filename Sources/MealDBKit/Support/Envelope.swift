import Foundation

/// A coding key made at run time, for TheMealDB's numbered fields (`strIngredient1` …).
struct DynamicKey: CodingKey, Hashable {
    let stringValue: String
    var intValue: Int? { nil }

    init(_ string: String) {
        stringValue = string
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        nil
    }
}

/// The wrapper around every list TheMealDB sends: `{"meals": [...]}` or `{"categories": [...]}`.
///
/// No match is `{"meals": null}`; some endpoints send a string such as `"Invalid ID"` or leave
/// the key out, and an empty body happens too. All of these read as an empty list.
struct Envelope<Item: Decodable>: Decodable {
    let items: [Item]

    /// The key of the list; `meals` unless the decoder's user info says otherwise.
    static var keyInfo: CodingUserInfoKey {
        CodingUserInfoKey(rawValue: "MealDBKit.envelopeKey")!
    }

    init(from decoder: any Decoder) throws {
        let name = decoder.userInfo[Self.keyInfo] as? String ?? "meals"
        let key = DynamicKey(name)
        let container = try decoder.container(keyedBy: DynamicKey.self)
        guard container.contains(key), try !container.decodeNil(forKey: key) else {
            items = []
            return
        }
        if (try? container.decode(String.self, forKey: key)) != nil {
            items = []
            return
        }
        items = try container.decode([Item].self, forKey: key)
    }
}

extension KeyedDecodingContainer where Key == DynamicKey {
    /// A trimmed string, or `nil` for a missing key, `null`, `""` or whitespace: TheMealDB uses
    /// all of them for "no value".
    func text(_ name: String) -> String? {
        let key = DynamicKey(name)
        guard let value = try? decodeIfPresent(String.self, forKey: key) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// A URL in a text field, or `nil` when it is blank or not a URL.
    func url(_ name: String) -> URL? {
        guard let text = text(name) else { return nil }
        return URL(string: text) ?? text.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed).flatMap(URL.init(string:))
    }

    /// Whether the key exists at all, even with a `null` value.
    func has(_ name: String) -> Bool {
        contains(DynamicKey(name))
    }
}
