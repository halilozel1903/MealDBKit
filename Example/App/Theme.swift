import SwiftUI
import MealDBKit
import MealDBUI

/// The look of *Recipes*, the demo app: warm paper with tomato red.
enum Theme {
    static let tomato = Color(red: 0.86, green: 0.30, blue: 0.16)
    static let background = Color(red: 0.99, green: 0.97, blue: 0.94)
    static let surface = Color.white
    static let cornerRadius: CGFloat = 18
}

extension View {
    /// The app's opaque navigation bar. iOS 26 bars are transparent by default, and an inline
    /// title over scrolled photos would be unreadable.
    @MainActor
    func kitchenNavigationBar() -> some View {
        toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }

    /// A rounded white surface behind grouped content.
    @MainActor
    func cardBackground() -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
    }
}

/// A section title with an optional count: "Ingredients 8".
struct SectionHeader: View {
    let title: String
    let count: Int?

    init(_ title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Color.primary)
            if let count {
                Text(String(count))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.tomato)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The data credit shown under lists. Verbatim, so the domain is not turned into a link.
struct DataCredit: View {
    var body: some View {
        Text(verbatim: "Recipes and photos from themealdb.com")
            .font(.footnote)
            .foregroundStyle(Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }
}

/// A cuisine with its flag: "🇮🇹 Italian".
struct AreaLabel: View {
    let area: MealArea

    var body: some View {
        Label {
            Text(area.name)
        } icon: {
            if let flag = area.flag {
                Text(flag)
            } else {
                Image(systemName: "globe")
                    .foregroundStyle(Theme.tomato)
            }
        }
    }
}
