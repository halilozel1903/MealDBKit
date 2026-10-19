import Foundation
import Testing
@testable import MealDBKit

@Suite("MealDBClient requests")
struct ClientTests {
    @Test func searchByName() async throws {
        let stub = StubbedClient { _ in try .json("search-arrabiata") }
        let meals = try await stub.client.searchMeals(name: " Arrabiata ")

        let ids: [String] = ["52771"]
        #expect(meals.map(\.id) == ids)
        #expect(stub.lastPath == "/api/json/v1/1/search.php")
        #expect(stub.lastQueryValue("s") == "Arrabiata")
    }

    @Test func headers() async throws {
        let stub = StubbedClient { _ in try .json("search-arrabiata") }
        _ = try await stub.client.searchMeals(name: "Arrabiata")

        let request = try #require(stub.requests.last)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        let agent = request.value(forHTTPHeaderField: "User-Agent") ?? ""
        #expect(agent.hasPrefix("MealDBKit"))
    }

    @Test func apiKeyIsAPathComponent() async throws {
        let stub = StubbedClient(apiKey: "supporter-key") { _ in try .json("meals-null") }
        _ = try await stub.client.categoryNames()

        #expect(stub.lastPath == "/api/json/v1/supporter-key/list.php")
    }

    @Test func noMatchesIsEmptyNotAnError() async throws {
        let stub = StubbedClient { _ in try .json("meals-null") }

        #expect(try await stub.client.searchMeals(name: "zzzz").isEmpty)
        #expect(try await stub.client.meals(inCategory: "Nothing").isEmpty)
        #expect(try await stub.client.meal(id: "1") == nil)
    }

    @Test func firstLetter() async throws {
        let stub = StubbedClient { _ in try .json("search-arrabiata") }
        _ = try await stub.client.meals(startingWith: "S")

        #expect(stub.lastPath == "/api/json/v1/1/search.php")
        #expect(stub.lastQueryValue("f") == "s")
    }

    @Test func firstLetterMustBeALetter() async throws {
        let stub = StubbedClient { _ in try .json("search-arrabiata") }
        await #expect(throws: MealDBError.self) {
            _ = try await stub.client.meals(startingWith: "?")
        }
        await #expect(throws: MealDBError.self) {
            _ = try await stub.client.meals(startingWith: "é")
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func lookupByID() async throws {
        let stub = StubbedClient { _ in try .json("lookup-52772") }
        let meal = try #require(try await stub.client.meal(id: 52772))

        #expect(meal.name == "Teriyaki Chicken Casserole")
        #expect(meal.ingredients.count == 9)
        #expect(stub.lastPath == "/api/json/v1/1/lookup.php")
        #expect(stub.lastQueryValue("i") == "52772")
    }

    @Test func blankIDSendsNothing() async throws {
        let stub = StubbedClient { _ in try .json("lookup-52772") }
        #expect(try await stub.client.meal(id: "  ") == nil)
        #expect(stub.requests.isEmpty)
    }

    @Test func severalMealsKeepTheirOrder() async throws {
        let stub = StubbedClient { request in
            switch request.queryValue("i") {
            case "52771": return try .json("search-arrabiata")
            case "52772": return try .json("lookup-52772")
            default: return try .json("meals-null")
            }
        }
        let meals = try await stub.client.meals(ids: ["52772", "404", "52771", "52772"])

        let ids: [String] = ["52772", "52771"]
        #expect(meals.map(\.id) == ids)
        #expect(stub.requests.count == 3)
    }

    @Test func randomMeal() async throws {
        let stub = StubbedClient { _ in try .json("lookup-52772") }
        let meal = try await stub.client.randomMeal()

        #expect(meal.id == "52772")
        #expect(stub.lastPath == "/api/json/v1/1/random.php")
        #expect(stub.lastQuery.isEmpty)
    }

    @Test func randomMealWithoutAResultThrows() async throws {
        let stub = StubbedClient { _ in try .json("meals-null") }
        await #expect(throws: MealDBError.self) {
            _ = try await stub.client.randomMeal()
        }
    }

    @Test func categoriesUseTheirOwnKey() async throws {
        let stub = StubbedClient { _ in try .json("categories") }
        let categories = try await stub.client.categories()

        #expect(categories.count == 3)
        #expect(stub.lastPath == "/api/json/v1/1/categories.php")
    }

    @Test func lists() async throws {
        let stub = StubbedClient { request in
            if request.queryValue("c") == "list" { return try .json("list-categories") }
            if request.queryValue("a") == "list" { return try .json("list-areas") }
            return try .json("list-ingredients")
        }

        let names = try await stub.client.categoryNames()
        let expectedNames: [String] = ["Beef", "Breakfast", "Chicken", "Dessert"]
        #expect(names == expectedNames)
        #expect(stub.lastQueryValue("c") == "list")

        let areas = try await stub.client.areas()
        #expect(areas.count == 4)
        #expect(stub.lastQueryValue("a") == "list")

        let ingredients = try await stub.client.ingredients()
        #expect(ingredients.count == 3)
        #expect(stub.lastQueryValue("i") == "list")
    }

    @Test func filters() async throws {
        let stub = StubbedClient { _ in try .json("filter-seafood") }

        let seafood = try await stub.client.meals(inCategory: "Seafood")
        #expect(seafood.count == 3)
        #expect(stub.lastPath == "/api/json/v1/1/filter.php")
        #expect(stub.lastQueryValue("c") == "Seafood")

        _ = try await stub.client.meals(from: MealArea(name: "Canadian"))
        #expect(stub.lastQueryValue("a") == "Canadian")

        _ = try await stub.client.meals(withIngredient: " Chicken  Breast ")
        #expect(stub.lastQueryValue("i") == "chicken_breast")
    }

    @Test func plusIsEncoded() async throws {
        let stub = StubbedClient { _ in try .json("meals-null") }
        _ = try await stub.client.searchMeals(name: "salt+pepper & co")

        let query = stub.requests.last?.url?.query ?? ""
        #expect(query.contains("%2B"))
        #expect(query.contains("%26"))
        #expect(stub.lastQueryValue("s") == "salt+pepper & co")
    }

    @Test func httpErrors() async throws {
        let stub = StubbedClient { _ in .status(503) }
        await #expect(throws: MealDBError.self) {
            _ = try await stub.client.categories()
        }
        do {
            _ = try await stub.client.categories()
            Issue.record("Expected an error")
        } catch let MealDBError.http(statusCode, url) {
            #expect(statusCode == 503)
            #expect(url.path == "/api/json/v1/1/categories.php")
        }
    }

    @Test func transportErrors() async throws {
        let stub = StubbedClient { _ in throw URLError(.badServerResponse) }
        do {
            _ = try await stub.client.areas()
            Issue.record("Expected an error")
        } catch let MealDBError.transport(error) {
            #expect(error.code == .badServerResponse)
        }
    }

    @Test func malformedResponses() async throws {
        let stub = StubbedClient { _ in .raw(#"{"meals": [{"strMeal": "No id"}]}"#) }
        do {
            _ = try await stub.client.searchMeals(name: "x")
            Issue.record("Expected an error")
        } catch let MealDBError.decoding(type, _) {
            #expect(type == "[Meal]")
        }
    }
}
