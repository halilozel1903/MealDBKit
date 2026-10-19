import SwiftUI
import MealDBKit

/// A meal for grids: the square `/preview` photo with the name below it.
///
/// ```swift
/// LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))]) {
///     ForEach(meals) { MealCard(meal: $0) }
/// }
/// ```
public struct MealCard: View {
    private let name: String
    private let photo: URL?
    private let subtitle: String?

    /// A card for a meal from a filter.
    public init(meal: MealSummary, subtitle: String? = nil) {
        name = meal.name
        photo = meal.thumbnailURL(size: .preview)
        self.subtitle = subtitle
    }

    /// A card for a full meal; the subtitle is its category and cuisine unless you give one.
    public init(meal: Meal, subtitle: String? = nil) {
        name = meal.name
        photo = meal.thumbnailURL(size: .preview)
        self.subtitle = subtitle ?? MealDBFormat.origin(of: meal)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MealDBImage(url: photo)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06))
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 2)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A meal for lists: a rounded photo with the name and an optional subtitle.
public struct MealRow: View {
    private let name: String
    private let photo: URL?
    private let subtitle: String?

    public init(meal: MealSummary, subtitle: String? = nil) {
        name = meal.name
        photo = meal.thumbnailURL(size: .preview)
        self.subtitle = subtitle
    }

    public init(meal: Meal, subtitle: String? = nil) {
        name = meal.name
        photo = meal.thumbnailURL(size: .preview)
        self.subtitle = subtitle ?? MealDBFormat.origin(of: meal)
    }

    public var body: some View {
        HStack(spacing: 14) {
            MealDBImage(url: photo)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// A category for grids: its picture on a soft tile, with the name.
public struct CategoryTile: View {
    private let category: MealCategory
    private let tint: Color

    public init(category: MealCategory, tint: Color = .orange) {
        self.category = category
        self.tint = tint
    }

    public var body: some View {
        VStack(spacing: 6) {
            MealDBImage(url: category.thumbnailURL, contentMode: .fit) {
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundStyle(tint.opacity(0.5))
            }
            .frame(height: 74)
            .padding(.horizontal, 10)
            .padding(.top, 12)
            Text(category.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// An ingredient of a recipe: its picture, its name and the measure.
public struct IngredientRow: View {
    private let ingredient: MealIngredient

    public init(ingredient: MealIngredient) {
        self.ingredient = ingredient
    }

    public var body: some View {
        HStack(spacing: 12) {
            MealDBImage(url: ingredient.imageURL(size: .small), contentMode: .fit) {
                Image(systemName: "leaf")
                    .foregroundStyle(Color.secondary)
            }
            .frame(width: 44, height: 44)
            .padding(4)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(MealDBFormat.ingredientName(ingredient.name))
                .font(.body)
                .foregroundStyle(Color.primary)
                .lineLimit(2)
            Spacer(minLength: 8)
            if !ingredient.measure.isEmpty {
                Text(ingredient.measure)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Numbered instruction steps.
public struct InstructionSteps: View {
    private let steps: [String]
    private let tint: Color

    public init(steps: [String], tint: Color = .orange) {
        self.steps = steps
        self.tint = tint
    }

    /// The steps of a meal.
    public init(meal: Meal, tint: Color = .orange) {
        self.init(steps: meal.instructionSteps, tint: tint)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text(String(index + 1))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.white)
                        .frame(width: 26, height: 26)
                        .background(tint, in: Circle())
                    Text(step)
                        .font(.body)
                        .padding(.top, 2)
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Step " + String(index + 1) + ". " + step)
            }
        }
    }
}

/// Small capsules for a meal's category, cuisine and tags, wrapping onto new lines.
public struct TagChips: View {
    private let tags: [String]
    private let tint: Color

    public init(_ tags: [String], tint: Color = .orange) {
        self.tags = tags
        self.tint = tint
    }

    public var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.12), in: Capsule())
            }
        }
    }
}

/// Lays children out in rows, wrapping when a row is full.
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

/// Text helpers for meals.
public enum MealDBFormat {
    /// "Vegetarian · Italian", or whichever of the two the meal has.
    public static func origin(of meal: Meal) -> String? {
        let parts = [meal.category, meal.area].compactMap { $0 }.filter { $0 != "Unknown" }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// TheMealDB writes some ingredients in lower case: "penne rigate" → "Penne rigate".
    public static func ingredientName(_ name: String) -> String {
        guard let first = name.first, first.isLowercase else { return name }
        return first.uppercased() + name.dropFirst()
    }

    /// "1 ingredient", "8 ingredients".
    public static func count(_ count: Int, _ noun: String) -> String {
        String(count) + " " + (count == 1 ? noun : noun + "s")
    }
}
