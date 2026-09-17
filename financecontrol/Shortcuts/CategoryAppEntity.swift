//
//  CategoryAppEntity.swift
//  Galla
//
//  Siri Shortcuts support — exposes expense categories as pickable entities.
//

import AppIntents
import CoreData

@available(iOS 16.0, *)
struct CategoryAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static var defaultQuery = CategoryEntityQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(ShortcutCategoryDisplay.title(for: name))")
    }
}

private enum ShortcutCategoryDisplay {
    static func title(for category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard leadingEmoji(in: trimmed) == nil else { return trimmed }
        return "\(emoji(for: trimmed))  \(trimmed)"
    }

    private static func emoji(for category: String) -> String {
        let value = category.lowercased()
        if value.contains("food") || value.contains("lunch") || value.contains("restaurant") { return "🍽️" }
        if value.contains("grocer") { return "🛒" }
        if value.contains("transport") || value.contains("uber") || value.contains("commute") { return "🚕" }
        if value.contains("house") || value.contains("housing") || value.contains("rent") { return "🏠" }
        if value.contains("util") || value.contains("bill") { return "💡" }
        if value.contains("shop") { return "🛍️" }
        if value.contains("cloth") { return "👕" }
        if value.contains("coffee") { return "☕️" }
        if value.contains("entertain") || value.contains("movie") { return "🍿" }
        if value.contains("going out") || value.contains("nightlife") { return "🍻" }
        if value.contains("subscription") { return "📅" }
        if value.contains("health") { return "💊" }
        if value.contains("travel") { return "✈️" }
        return "🧾"
    }

    private static func leadingEmoji(in category: String) -> Character? {
        guard let first = category.first else { return nil }
        let isEmoji = first.unicodeScalars.contains {
            $0.properties.isEmojiPresentation || $0.value == 0xFE0F
        }
        return isEmoji ? first : nil
    }
}

@available(iOS 16.0, *)
struct CategoryEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CategoryAppEntity] {
        let context = DataManager.shared.context
        return try await context.perform {
            let request = CategoryEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "isShadowed == false AND id IN %@",
                identifiers as CVarArg
            )
            return try context.fetch(request).compactMap(Self.makeEntity)
        }
    }

    func suggestedEntities() async throws -> [CategoryAppEntity] {
        let context = DataManager.shared.context
        return try await context.perform {
            let request = CategoryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isShadowed == false")
            return try context.fetch(request)
                .compactMap(Self.makeEntity)
                .sorted(by: Self.categorySort)
        }
    }

    private static func makeEntity(_ category: CategoryEntity) -> CategoryAppEntity? {
        guard let id = category.id, let name = category.name else { return nil }
        return CategoryAppEntity(id: id, name: name)
    }

    private static func categorySort(_ first: CategoryAppEntity, _ second: CategoryAppEntity) -> Bool {
        let firstKey = canonicalName(first.name)
        let secondKey = canonicalName(second.name)
        let firstOrder = preferredOrder[firstKey] ?? Int.max
        let secondOrder = preferredOrder[secondKey] ?? Int.max

        if firstOrder == secondOrder {
            return firstKey.localizedCaseInsensitiveCompare(secondKey) == .orderedAscending
        }
        return firstOrder < secondOrder
    }

    private static let preferredOrder = Dictionary(
        uniqueKeysWithValues: [
            "housing", "food", "groceries", "utilities", "transportation",
            "shopping", "clothes", "going out", "entertainment", "subscription",
            "extras", "salary", "investments"
        ].enumerated().map { ($0.element, $0.offset) }
    )

    private static func canonicalName(_ name: String) -> String {
        guard let firstLetterOrNumber = name.range(
            of: #"[\p{L}\p{N}]"#,
            options: .regularExpression
        ) else {
            return name.lowercased()
        }

        return name[firstLetterOrNumber.lowerBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
