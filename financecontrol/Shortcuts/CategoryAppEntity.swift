//
//  CategoryAppEntity.swift
//  Squirrel
//
//  Siri Shortcuts support — exposes categories as pickable entities.
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
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 16.0, *)
struct CategoryEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CategoryAppEntity] {
        let context = DataManager.shared.context
        return try await context.perform {
            let request = CategoryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isShadowed == false AND id IN %@", identifiers as CVarArg)
            let results = try context.fetch(request)
            return results.compactMap { entity in
                guard let id = entity.id, let name = entity.name else { return nil }
                return CategoryAppEntity(id: id, name: name)
            }
        }
    }

    func suggestedEntities() async throws -> [CategoryAppEntity] {
        let context = DataManager.shared.context
        return try await context.perform {
            let request = CategoryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isShadowed == false")
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            let results = try context.fetch(request)
            return results.compactMap { entity in
                guard let id = entity.id, let name = entity.name else { return nil }
                return CategoryAppEntity(id: id, name: name)
            }
        }
    }
}
