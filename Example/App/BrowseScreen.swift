import SwiftUI
import MealDBKit
import MealDBUI

/// iPhone: the category grid, or every cuisine, with a button for a random recipe.
struct BrowseScreen: View {
    enum BrowseSection: String, CaseIterable, Identifiable {
        case categories = "Categories"
        case cuisines = "Cuisines"

        var id: Self { self }
    }

    let scene: ScreenshotScene?

    @Environment(Kitchen.self) private var kitchen
    @State private var section: BrowseSection = .categories

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            switch section {
            case .categories:
                categoryGrid
            case .cuisines:
                cuisineList
            }
            DataCredit()
        }
        .background(Theme.background)
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Browse by", selection: $section) {
                ForEach(BrowseSection.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.background)
        }
        .navigationTitle("Recipes")
        // iOS 26 leaves the large title out with a pinned bar background; keep it inline.
        .navigationBarTitleDisplayMode(.inline)
        .kitchenNavigationBar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.random) {
                    Label("Surprise me", systemImage: "dice")
                }
            }
        }
        .task {
            await kitchen.loadCategories()
        }
        .task(id: section) {
            if section == .cuisines {
                await kitchen.loadAreas()
            }
        }
        .signalsScreenshotReady(scene, when: !kitchen.categories.isEmpty)
    }

    @ViewBuilder
    private var categoryGrid: some View {
        if let message = kitchen.categoriesError, kitchen.categories.isEmpty {
            ContentUnavailableView("Couldn't load categories", systemImage: "wifi.exclamationmark", description: Text(message))
                .padding(.top, 80)
        } else if kitchen.categories.isEmpty {
            ProgressView()
                .padding(.top, 120)
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(kitchen.categories) { category in
                    NavigationLink(value: Route.meals(.category(category.name))) {
                        CategoryTile(category: category, tint: Theme.tomato)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var cuisineList: some View {
        if let message = kitchen.areasError, kitchen.areas.isEmpty {
            ContentUnavailableView("Couldn't load cuisines", systemImage: "wifi.exclamationmark", description: Text(message))
                .padding(.top, 80)
        } else if kitchen.areas.isEmpty {
            ProgressView()
                .padding(.top, 120)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(kitchen.areas) { area in
                    NavigationLink(value: Route.meals(.area(area.name))) {
                        HStack {
                            AreaLabel(area: area)
                                .font(.body)
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                        .padding(.leading, 16)
                }
            }
            .cardBackground()
            .padding(16)
        }
    }
}

/// The meals of a category, a cuisine or a main ingredient, as a photo grid.
struct MealListScreen: View {
    let filter: MealFilter
    let scene: ScreenshotScene?

    @Environment(Kitchen.self) private var kitchen
    @State private var meals: [MealSummary]?
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 14)]

    init(filter: MealFilter, scene: ScreenshotScene? = nil) {
        self.filter = filter
        self.scene = scene
    }

    var body: some View {
        ScrollView {
            if let meals {
                if meals.isEmpty {
                    ContentUnavailableView(
                        "No recipes",
                        systemImage: "fork.knife",
                        description: Text("TheMealDB has no recipes for " + filter.title + ".")
                    )
                    .padding(.top, 80)
                } else {
                    header(count: meals.count)
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(meals) { meal in
                            NavigationLink(value: Route.meal(meal.id)) {
                                MealCard(meal: meal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    DataCredit()
                }
            } else if let errorMessage {
                ContentUnavailableView("Couldn't load recipes", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                    .padding(.top, 80)
            } else {
                ProgressView()
                    .padding(.top, 120)
            }
        }
        .background(Theme.background)
        .navigationTitle(filter.title)
        .navigationBarTitleDisplayMode(.inline)
        .kitchenNavigationBar()
        .task(id: filter) {
            await load()
        }
        .signalsScreenshotReady(scene, when: meals?.isEmpty == false)
    }

    @ViewBuilder
    private func header(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if case let .category(name) = filter, let category = kitchen.category(named: name) {
                Text(category.cleanDescription)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(3)
            }
            Text(MealDBFormat.count(count, "recipe"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.tomato)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func load() async {
        errorMessage = nil
        meals = kitchen.cachedMeals(for: filter)
        if case .category = filter {
            await kitchen.loadCategories()
        }
        guard meals == nil else { return }
        do {
            meals = try await kitchen.meals(for: filter)
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// A random recipe, loaded when the page opens; "Another one" loads a new one.
struct RandomMealView: View {
    @Environment(Kitchen.self) private var kitchen
    @State private var mealID: String?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let mealID {
                MealDetailView(mealID: mealID)
                    .id(mealID)
            } else if let errorMessage {
                ContentUnavailableView("Couldn't load a recipe", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await load() }
                } label: {
                    Label("Another one", systemImage: "dice")
                }
            }
        }
        .task {
            if mealID == nil {
                await load()
            }
        }
    }

    private func load() async {
        errorMessage = nil
        do {
            mealID = try await kitchen.randomMeal().id
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
