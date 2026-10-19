import SwiftUI
import MealDBKit
import MealDBUI

/// iPad: a three-column split view. The sidebar lists categories and cuisines, the middle column
/// lists their meals, and the detail column shows the selected recipe.
struct BrowseSplitView: View {
    let scene: ScreenshotScene?

    @Environment(Kitchen.self) private var kitchen
    @State private var filter: MealFilter? = nil
    @State private var selectedMeal: String? = nil
    @State private var detailPath: [Route] = []
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var loadingRandom = false

    init(scene: ScreenshotScene?) {
        self.scene = scene
        // The browse scene opens on Vegetarian with the Arrabiata selected.
        if scene == .browse {
            _filter = State(initialValue: ScreenshotScene.browseFilter)
            _selectedMeal = State(initialValue: ScreenshotScene.mealID)
        } else {
            _filter = State(initialValue: .category("Beef"))
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } content: {
            if let filter {
                MealColumn(filter: filter, selection: $selectedMeal)
            } else {
                ContentUnavailableView("Pick a category", systemImage: "square.grid.2x2")
            }
        } detail: {
            NavigationStack(path: $detailPath) {
                Group {
                    if let selectedMeal {
                        MealDetailView(mealID: selectedMeal, scene: scene == .browse ? scene : nil)
                            .id(selectedMeal)
                    } else {
                        ContentUnavailableView("Pick a recipe", systemImage: "fork.knife", description: Text("Choose a meal from the list."))
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    RouteDestination(route)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: filter) { detailPath = [] }
        .onChange(of: selectedMeal) { detailPath = [] }
        .task {
            await kitchen.loadCategories()
        }
        .task {
            await kitchen.loadAreas()
        }
    }

    private var sidebar: some View {
        List(selection: $filter) {
            Section("Categories") {
                if kitchen.categories.isEmpty {
                    if let message = kitchen.categoriesError {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    } else {
                        ProgressView()
                    }
                }
                ForEach(kitchen.categories) { category in
                    Label {
                        Text(category.name)
                    } icon: {
                        MealDBImage(url: category.thumbnailURL, contentMode: .fit) {
                            Image(systemName: "fork.knife")
                        }
                        .frame(width: 30, height: 24)
                    }
                    .tag(MealFilter.category(category.name))
                }
            }
            Section("Cuisines") {
                ForEach(kitchen.areas) { area in
                    AreaLabel(area: area)
                        .tag(MealFilter.area(area.name))
                }
            }
        }
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await showRandomMeal() }
                } label: {
                    Label("Surprise me", systemImage: "dice")
                }
                .disabled(loadingRandom)
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
    }

    private func showRandomMeal() async {
        loadingRandom = true
        defer { loadingRandom = false }
        if let meal = try? await kitchen.randomMeal() {
            selectedMeal = meal.id
        }
    }
}

/// iPad: the meals of the sidebar's selection.
private struct MealColumn: View {
    let filter: MealFilter
    @Binding var selection: String?

    @Environment(Kitchen.self) private var kitchen
    @State private var meals: [MealSummary]?
    @State private var errorMessage: String?
    @State private var searchText = ""

    var body: some View {
        let shown = (meals ?? []).filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
        List(selection: $selection) {
            if let errorMessage {
                ContentUnavailableView("Couldn't load recipes", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else if let meals {
                if meals.isEmpty {
                    ContentUnavailableView("No recipes", systemImage: "fork.knife")
                } else {
                    Section {
                        ForEach(shown) { meal in
                            MealRow(meal: meal)
                                .tag(meal.id)
                        }
                    } header: {
                        Text(MealDBFormat.count(meals.count, "recipe"))
                            .textCase(nil)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(filter.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Filter " + filter.title)
        .task(id: filter) {
            await load()
        }
        .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
    }

    private func load() async {
        errorMessage = nil
        searchText = ""
        meals = kitchen.cachedMeals(for: filter)
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
