import SwiftUI
import MealDBKit
import MealDBUI

/// What the search page shows: meals by name, or every meal starting with a letter.
enum MealQuery: Hashable {
    case name(String)
    case letter(Character)
}

/// Search by name, or browse A to Z by first letter.
struct SearchScreen: View {
    let scene: ScreenshotScene?

    @Environment(Kitchen.self) private var kitchen
    @State private var searchText: String
    @State private var letter: Character = "a"
    @State private var results: [Meal]?
    @State private var loadedQuery: MealQuery?
    @State private var errorMessage: String?

    private static let letters: [Character] = Array("abcdefghijklmnopqrstuvwxyz")

    init(scene: ScreenshotScene?) {
        self.scene = scene
        _searchText = State(initialValue: scene == .search ? ScreenshotScene.searchText : "")
    }

    private var query: MealQuery {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? .letter(letter) : .name(text)
    }

    var body: some View {
        List {
            if case .letter = query {
                letterPicker
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            if let errorMessage {
                ContentUnavailableView("Couldn't search", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                    .listRowBackground(Color.clear)
            } else if let results, loadedQuery == query {
                if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(results) { meal in
                            NavigationLink(value: Route.meal(meal.id)) {
                                MealRow(meal: meal)
                            }
                        }
                    } header: {
                        Text(MealDBFormat.count(results.count, "recipe"))
                            .textCase(nil)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .kitchenNavigationBar()
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Meal name, such as Arrabiata")
        .autocorrectionDisabled()
        .task(id: query) {
            await run(query)
        }
        .signalsScreenshotReady(scene, when: loadedQuery == query && results?.isEmpty == false)
    }

    private var letterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Self.letters, id: \.self) { item in
                    Button {
                        letter = item
                    } label: {
                        Text(String(item).uppercased())
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(item == letter ? Color.white : Color.primary)
                            .background(item == letter ? Theme.tomato : Theme.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Meals starting with " + String(item).uppercased())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func run(_ query: MealQuery) async {
        errorMessage = nil
        do {
            switch query {
            case let .name(text):
                // Wait for typing to pause.
                if loadedQuery != nil {
                    try await Task.sleep(for: .milliseconds(400))
                }
                results = try await kitchen.search(name: text)
            case let .letter(letter):
                results = try await kitchen.meals(startingWith: letter)
            }
            loadedQuery = query
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }
}
