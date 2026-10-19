import SwiftUI
import MealDBKit
import MealDBUI

@main
struct RecipesApp: App {
    @State private var kitchen = Kitchen()
    private let scene = ScreenshotScene.current

    var body: some Scene {
        WindowGroup {
            RootView(scene: scene)
                .environment(kitchen)
                // Screenshot scenes count their image loads, to report ready once all are on screen.
                .mealDBImageLoader(scene == nil ? MealDBImageLoader.urlSession : ScreenshotScene.imageLoader)
                .preferredColorScheme(.light)
                .tint(Theme.tomato)
        }
    }
}

/// A split view with a sidebar where there is room (iPad), tabs otherwise (iPhone).
struct RootView: View {
    let scene: ScreenshotScene?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if usesSplitView {
            BrowseSplitView(scene: scene)
        } else {
            PhoneRootView(scene: scene)
        }
    }

    private var usesSplitView: Bool {
        switch scene {
        case .browse: return true
        case .some: return false
        case nil: return horizontalSizeClass == .regular
        }
    }
}

/// The page for a route.
struct RouteDestination: View {
    let route: Route
    let scene: ScreenshotScene?

    init(_ route: Route, scene: ScreenshotScene? = nil) {
        self.route = route
        self.scene = scene
    }

    var body: some View {
        switch route {
        case let .meals(filter):
            MealListScreen(filter: filter, scene: scene == .meals ? scene : nil)
        case let .meal(id):
            MealDetailView(mealID: id, scene: scene == .meal ? scene : nil)
        case .random:
            RandomMealView()
        }
    }
}

/// iPhone: a Browse tab (categories and cuisines) and a Search tab, each with its own stack.
struct PhoneRootView: View {
    enum Tab: Hashable {
        case browse
        case search
    }

    let scene: ScreenshotScene?
    @State private var tab: Tab
    @State private var browsePath: [Route]
    @State private var searchPath: [Route] = []

    init(scene: ScreenshotScene?) {
        self.scene = scene
        _tab = State(initialValue: scene == .search ? .search : .browse)
        // Screenshot scenes start on their page, pushed without an animation.
        switch scene {
        case .meals: _browsePath = State(initialValue: [.meals(ScreenshotScene.mealsFilter)])
        case .meal: _browsePath = State(initialValue: [.meal(ScreenshotScene.mealID)])
        default: _browsePath = State(initialValue: [])
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $browsePath) {
                BrowseScreen(scene: scene == .categories ? scene : nil)
                    .navigationDestination(for: Route.self) { route in
                        RouteDestination(route, scene: scene)
                    }
            }
            .tabItem { Label("Browse", systemImage: "square.grid.2x2.fill") }
            .tag(Tab.browse)

            NavigationStack(path: $searchPath) {
                SearchScreen(scene: scene == .search ? scene : nil)
                    .navigationDestination(for: Route.self) { route in
                        RouteDestination(route)
                    }
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(Tab.search)
        }
    }
}
