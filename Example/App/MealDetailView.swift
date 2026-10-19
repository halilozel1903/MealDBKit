import SwiftUI
import MealDBKit
import MealDBUI

/// A recipe: the photo, category, cuisine and tags, the YouTube video, every ingredient with its
/// picture and measure, and the numbered instructions. Tapping an ingredient lists the meals
/// with it.
struct MealDetailView: View {
    let mealID: String
    let scene: ScreenshotScene?

    @Environment(Kitchen.self) private var kitchen
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var meal: Meal?
    @State private var errorMessage: String?

    init(mealID: String, scene: ScreenshotScene? = nil) {
        self.mealID = mealID
        self.scene = scene
    }

    var body: some View {
        Group {
            if let meal {
                content(meal)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Couldn't load this recipe",
                    systemImage: "fork.knife.circle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .navigationTitle(meal?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .kitchenNavigationBar()
        .task(id: mealID) {
            await load()
        }
        .signalsScreenshotReady(scene, when: isComplete)
    }

    /// Whether the recipe has loaded, and on iPad the category list and sidebar beside it.
    private var isComplete: Bool {
        guard meal != nil else { return false }
        guard scene == .browse else { return true }
        return !kitchen.categories.isEmpty && kitchen.cachedMeals(for: ScreenshotScene.browseFilter)?.isEmpty == false
    }

    private func content(_ meal: Meal) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MealDBImage(url: meal.thumbnailURL)
                    .aspectRatio(horizontalSizeClass == .regular ? 1.6 : 4.0 / 3.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .accessibilityLabel(Text("Photo of " + meal.name))

                VStack(alignment: .leading, spacing: 10) {
                    Text(meal.name)
                        .font(.system(.title, design: .serif).bold())
                        .foregroundStyle(Color.primary)
                    TagChips(chips(for: meal), tint: Theme.tomato)
                }

                if let youtube = meal.youtubeURL {
                    Link(destination: youtube) {
                        Label("Watch on YouTube", systemImage: "play.rectangle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.85, green: 0.12, blue: 0.12))
                }

                ingredients(meal)
                instructions(meal)

                if let source = meal.sourceURL {
                    Link(destination: source) {
                        Label("Original recipe", systemImage: "safari")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                DataCredit()
            }
            .padding(16)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private func chips(for meal: Meal) -> [String] {
        var chips: [String] = []
        if let category = meal.category {
            chips.append(category)
        }
        if let area = meal.mealArea, area.name != "Unknown" {
            chips.append([area.flag, area.name].compactMap { $0 }.joined(separator: " "))
        }
        chips += meal.tags.filter { $0 != meal.category && $0 != meal.area }
        return chips
    }

    private func ingredients(_ meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Ingredients", count: meal.ingredients.count)
            VStack(spacing: 0) {
                ForEach(meal.ingredients) { ingredient in
                    NavigationLink(value: Route.meals(.ingredient(ingredient.name))) {
                        IngredientRow(ingredient: ingredient)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if ingredient.id != meal.ingredients.last?.id {
                        Divider()
                            .padding(.leading, 74)
                    }
                }
            }
            .padding(.vertical, 4)
            .cardBackground()
        }
    }

    private func instructions(_ meal: Meal) -> some View {
        let steps = meal.instructionSteps
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Instructions", count: steps.count)
            InstructionSteps(steps: steps, tint: Theme.tomato)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground()
        }
    }

    private func load() async {
        errorMessage = nil
        if let cached = kitchen.cachedMeal(id: mealID) {
            meal = cached
            return
        }
        meal = nil
        do {
            meal = try await kitchen.meal(id: mealID)
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }
}
