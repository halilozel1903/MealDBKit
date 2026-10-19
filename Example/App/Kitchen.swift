import Foundation
import Observation
import MealDBKit
import MealDBUI

/// What a meal list shows: the meals of a category, a cuisine or a main ingredient.
enum MealFilter: Hashable {
    case category(String)
    case area(String)
    case ingredient(String)

    var title: String {
        switch self {
        case let .category(name), let .area(name):
            return name
        case let .ingredient(name):
            return MealDBFormat.ingredientName(name)
        }
    }
}

/// A page the app can push.
enum Route: Hashable {
    case meals(MealFilter)
    case meal(String)
    case random
}

/// The app's data, all from one `MealDBClient` with the free test key. Lists and recipes are
/// kept once loaded, so going back and forth doesn't reload them.
@MainActor
@Observable
final class Kitchen {
    let client: MealDBClient

    private(set) var categories: [MealCategory] = []
    private(set) var categoriesError: String?
    private(set) var areas: [MealArea] = []
    private(set) var areasError: String?

    private var meals: [String: Meal] = [:]
    private var lists: [MealFilter: [MealSummary]] = [:]

    init(client: MealDBClient = .shared) {
        self.client = client
    }

    func loadCategories() async {
        guard categories.isEmpty else { return }
        do {
            categories = try await retrying { [client = self.client] in try await client.categories() }
            categoriesError = nil
        } catch {
            categoriesError = error.localizedDescription
        }
    }

    func loadAreas() async {
        guard areas.isEmpty else { return }
        do {
            areas = try await retrying { [client = self.client] in try await client.areas() }.sorted()
            areasError = nil
        } catch {
            areasError = error.localizedDescription
        }
    }

    func category(named name: String) -> MealCategory? {
        categories.first { $0.name == name }
    }

    /// The list for `filter` if it has been loaded.
    func cachedMeals(for filter: MealFilter) -> [MealSummary]? {
        lists[filter]
    }

    func meals(for filter: MealFilter) async throws -> [MealSummary] {
        if let cached = lists[filter] { return cached }
        let client = self.client
        let result: [MealSummary] = try await retrying {
            switch filter {
            case let .category(name): return try await client.meals(inCategory: name)
            case let .area(name): return try await client.meals(fromArea: name)
            case let .ingredient(name): return try await client.meals(withIngredient: name)
            }
        }
        lists[filter] = result
        return result
    }

    func cachedMeal(id: String) -> Meal? {
        meals[id]
    }

    func meal(id: String) async throws -> Meal {
        if let cached = meals[id] { return cached }
        guard let meal = try await retrying({ [client = self.client] in try await client.meal(id: id) }) else {
            throw KitchenError.noSuchMeal
        }
        meals[id] = meal
        return meal
    }

    func randomMeal() async throws -> Meal {
        let meal = try await retrying { [client = self.client] in try await client.randomMeal() }
        meals[meal.id] = meal
        return meal
    }

    func search(name: String) async throws -> [Meal] {
        let found = try await retrying { [client = self.client] in try await client.searchMeals(name: name) }
        remember(found)
        return found
    }

    func meals(startingWith letter: Character) async throws -> [Meal] {
        let found = try await retrying { [client = self.client] in try await client.meals(startingWith: letter) }
        remember(found)
        return found
    }

    private func remember(_ found: [Meal]) {
        for meal in found {
            meals[meal.id] = meal
        }
    }

    /// Runs `operation`, trying again twice after a network failure.
    private func retrying<Value: Sendable>(_ operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
        var attempt = 0
        while true {
            do {
                return try await operation()
            } catch MealDBError.transport(let error) where attempt < 2 && error.code != .cancelled {
                attempt += 1
                try await Task.sleep(for: .seconds(Double(attempt)))
            } catch MealDBError.http(let status, _) where attempt < 2 && status >= 500 {
                attempt += 1
                try await Task.sleep(for: .seconds(Double(attempt)))
            }
        }
    }
}

enum KitchenError: LocalizedError {
    case noSuchMeal

    var errorDescription: String? {
        "TheMealDB has no recipe with this id."
    }
}
