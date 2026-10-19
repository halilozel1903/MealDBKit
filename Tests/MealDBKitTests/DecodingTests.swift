import Foundation
import Testing
@testable import MealDBKit

@Suite("Decoding TheMealDB's JSON")
struct DecodingTests {
    private func meals(_ fixture: String) throws -> [Meal] {
        try MealDBClient().decodeList(from: Fixture.data(fixture))
    }

    @Test func arrabiata() throws {
        let meal = try #require(try meals("search-arrabiata").first)

        #expect(meal.id == "52771")
        #expect(meal.name == "Spicy Arrabiata Penne")
        #expect(meal.alternateName == nil)
        #expect(meal.category == "Vegetarian")
        #expect(meal.area == "Italian")
        #expect(meal.thumbnailURL?.absoluteString == "https://www.themealdb.com/images/media/meals/ustsqw1468250014.jpg")
        let tags: [String] = ["Pasta", "Curry"]
        #expect(meal.tags == tags)
        #expect(meal.youtubeVideoID == "1IszT_guI08")
        #expect(meal.sourceURL == nil)
        #expect(meal.creativeCommonsConfirmed == nil)
    }

    @Test func flatIngredientsBecomeATypedList() throws {
        let meal = try #require(try meals("search-arrabiata").first)

        #expect(meal.ingredients.count == 8)
        let names: [String] = [
            "penne rigate", "olive oil", "garlic", "chopped tomatoes",
            "red chilli flakes", "italian seasoning", "basil", "Parmigiano-Reggiano",
        ]
        #expect(meal.ingredients.map(\.name) == names)
        let positions: [Int] = [1, 2, 3, 4, 5, 6, 7, 8]
        #expect(meal.ingredients.map(\.position) == positions)
        #expect(meal.ingredients[0].measure == "1 pound")
        // "1 tin " is trimmed.
        #expect(meal.ingredients[3].measure == "1 tin")
    }

    @Test func blankAndMissingIngredientFieldsAreSkipped() throws {
        let meal = try #require(try meals("meal-step-headings").first)

        // Position 2 has a whitespace name, so only its measure is there; it is skipped.
        let positions: [Int] = [1, 3, 4, 5]
        #expect(meal.ingredients.map(\.position) == positions)
        let names: [String] = ["Beef", "Onion", "Beef Stock", "Salt"]
        #expect(meal.ingredients.map(\.name) == names)
        let measures: [String] = ["1kg", "", "500ml", ""]
        #expect(meal.ingredients.map(\.measure) == measures)
    }

    @Test func blankStringsAreNil() throws {
        let meal = try #require(try meals("meal-step-headings").first)

        #expect(meal.alternateName == nil)
        #expect(meal.youtubeURL == nil)
        #expect(meal.youtubeVideoID == nil)
        #expect(meal.thumbnailURL?.absoluteString == "https://www.themealdb.com/images/media/meals/fixture.jpg")
        let tags: [String] = ["Stew", "Winter"]
        #expect(meal.tags == tags)
        #expect(meal.creativeCommonsConfirmed == true)
        #expect(meal.dateModified == "2026-01-01 10:00:00")
    }

    @Test func instructionStepsDropHeadingsAndNumbers() throws {
        let meal = try #require(try meals("meal-step-headings").first)

        let steps: [String] = [
            "Heat the oil in a large pan.",
            "Brown the meat in batches.",
            "Add the stock and simmer for 2 hours.",
            "Season to taste.",
            "Serve hot.",
            "1.5 kg of potatoes can be added with the stock.",
        ]
        #expect(meal.instructionSteps == steps)
    }

    @Test func instructionStepsSplitLines() throws {
        let meal = try #require(try meals("search-arrabiata").first)
        let steps = meal.instructionSteps

        #expect(steps.count == 3)
        #expect(steps.first?.hasPrefix("Bring a large pot of water to a boil.") == true)
        #expect(steps.last?.hasSuffix("serve warm.") == true)
    }

    @Test func stepMarkers() {
        #expect(MealInstructions.stripMarker("STEP 12") == "")
        #expect(MealInstructions.stripMarker("step 2. Fry") == "Fry")
        #expect(MealInstructions.stripMarker("7") == "")
        #expect(MealInstructions.stripMarker("10) Rest") == "Rest")
        #expect(MealInstructions.stripMarker("350F oven") == "350F oven")
        #expect(MealInstructions.stripMarker("2 eggs, beaten") == "2 eggs, beaten")
        #expect(MealInstructions.stripMarker("Stephen's sauce") == "Stephen's sauce")
        #expect(MealInstructions.stripMarker("2026. A year") == "2026. A year")
    }

    @Test func nullMealsIsEmpty() throws {
        #expect(try meals("meals-null").isEmpty)
        let summaries: [MealSummary] = try MealDBClient().decodeList(from: Fixture.data("meals-null"))
        #expect(summaries.isEmpty)
    }

    @Test func stringMealsIsEmpty() throws {
        #expect(try meals("meals-invalid-id").isEmpty)
    }

    @Test func emptyBodyAndMissingKeyAreEmpty() throws {
        let client = MealDBClient()
        let blank: [Meal] = try client.decodeList(from: Data())
        #expect(blank.isEmpty)
        let missing: [Meal] = try client.decodeList(from: Data("{}".utf8))
        #expect(missing.isEmpty)
    }

    @Test func malformedJSONThrows() throws {
        #expect(throws: MealDBError.self) {
            let _: [Meal] = try MealDBClient().decodeList(from: Data("[1, 2".utf8))
        }
    }

    @Test func encodingRoundTripsTheFlatShape() throws {
        let meal = try #require(try meals("search-arrabiata").first)
        let data = try JSONEncoder().encode(meal)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["strIngredient1"] as? String == "penne rigate")
        #expect(object["strMeasure8"] as? String == "spinkling")
        #expect(object["strIngredient20"] is NSNull)
        #expect(object["strTags"] as? String == "Pasta,Curry")

        let decoded = try JSONDecoder().decode(Meal.self, from: data)
        #expect(decoded == meal)
    }

    @Test func summaries() throws {
        let summaries: [MealSummary] = try MealDBClient().decodeList(from: Fixture.data("filter-seafood"))

        #expect(summaries.count == 3)
        #expect(summaries[0].id == "52959")
        #expect(summaries[0].name == "Baked salmon with fennel & tomatoes")
        #expect(summaries[0].thumbnailURL(size: .preview)?.absoluteString == "https://www.themealdb.com/images/media/meals/1548772327.jpg/preview")
    }

    @Test func categories() throws {
        let categories: [MealCategory] = try MealDBClient().decodeList(from: Fixture.data("categories"), key: "categories")

        let names: [String] = ["Beef", "Chicken", "Dessert"]
        #expect(categories.map(\.name) == names)
        #expect(categories[0].thumbnailURL?.lastPathComponent == "beef.png")
        #expect(categories[0].cleanDescription.hasSuffix("since prehistoric times."))
        #expect(categories[2].cleanDescription == "Dessert is a course that concludes a meal. The course usually consists of sweet foods.")
    }

    @Test func ingredientsList() throws {
        let ingredients: [Ingredient] = try MealDBClient().decodeList(from: Fixture.data("list-ingredients"))

        #expect(ingredients.count == 3)
        #expect(ingredients[0].thumbnailURL?.absoluteString == "https://www.themealdb.com/images/ingredients/chicken.png")
        #expect(ingredients[1].description == nil)
        #expect(ingredients[2].type == "Meat")
        #expect(ingredients[2].imageURL(size: .medium).absoluteString == "https://www.themealdb.com/images/ingredients/chicken%20breast-medium.png")
    }

    @Test func areas() throws {
        let areas: [MealArea] = try MealDBClient().decodeList(from: Fixture.data("list-areas"))

        #expect(areas.map(\.name).count == 4)
        #expect(areas[2].countryCode == "it")
        #expect(areas[2].flag == "🇮🇹")
        #expect(areas[1].flag == "🇬🇧")
        #expect(areas[3].flag == nil)
    }
}
