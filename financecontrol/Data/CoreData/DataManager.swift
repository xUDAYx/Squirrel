//
//  DataManager.swift
//  financecontrol
//
//  Created by PinkXaciD on R 5/07/05.
//

import CoreData

enum DefaultCategories {
    struct Category {
        let name: String
        let color: String
        let isIncome: Bool
    }

    static let all: [Category] = [
        .init(name: "🏠 Housing", color: "15", isIncome: false),
        .init(name: "🍽️ Food", color: "55", isIncome: false),
        .init(name: "🛒 Groceries", color: "90", isIncome: false),
        .init(name: "💡 Utilities", color: "130", isIncome: false),
        .init(name: "🚗 Transportation", color: "190", isIncome: false),
        .init(name: "🛍️ Shopping", color: "260", isIncome: false),
        .init(name: "👕 Clothes", color: "310", isIncome: false),
        .init(name: "🍻 Going out", color: "35", isIncome: false),
        .init(name: "🍿 Entertainment", color: "220", isIncome: false),
        .init(name: "📅 Subscription", color: "285", isIncome: false),
        .init(name: "🤹 Extras", color: "170", isIncome: false),
        .init(name: "💰 Salary", color: "75", isIncome: true),
        .init(name: "📊 Investments", color: "245", isIncome: true),
        .init(name: "🧑‍💼 Part-Time", color: "100", isIncome: true),
        .init(name: "🏦 Savings", color: "150", isIncome: true),
        .init(name: "🆘 Emergency Fund", color: "200", isIncome: true),
        .init(name: "💵 Tips", color: "50", isIncome: true),
        .init(name: "🏖️ Retirement Fund", color: "270", isIncome: true)
    ]

    static let orderByName = Dictionary(
        uniqueKeysWithValues: all.enumerated().map { ($0.element.name, $0.offset) }
    )

    static func canonicalKey(for name: String) -> String {
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

final class DataManager {
    static let shared = DataManager()

    private static let defaultCategoriesSeedKey = "gallaDefaultCategoriesSeeded"
    private static let defaultCategoriesSeedVersion = 4
    
    let container: NSPersistentContainer
    let context: NSManagedObjectContext
    lazy private(set) var backgroundContext: NSManagedObjectContext = container.newBackgroundContext()

    init() {
        let container =  NSPersistentCloudKitContainer(name: "DataContainer")
        
        if let storeDescription = container.persistentStoreDescriptions.first {
            if !NSUbiquitousKeyValueStore.default.bool(forKey: UDKey.iCloudSync.rawValue) {
                storeDescription.configuration = "Default"
                storeDescription.cloudKitContainerOptions = nil
            }
            
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                ErrorType(error: error).publish()
            }
        }
        
#if DEBUG
//        do {
//            try container.initializeCloudKitSchema()
//        } catch {
//            print(error)
//        }
#endif
        
        let context = container.viewContext
        context.name = "Main context"
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        
        try? context.setQueryGenerationFrom(.current)
        self.container = container
        self.context = context

        seedDefaultCategoriesIfNeeded()
    }

    private func seedDefaultCategoriesIfNeeded() {
        guard UserDefaults.standard.integer(forKey: Self.defaultCategoriesSeedKey) < Self.defaultCategoriesSeedVersion else {
            return
        }

        context.performAndWait {
            do {
                let request = CategoryEntity.fetchRequest()
                var existingCategories = try context.fetch(request)

                guard let description = NSEntityDescription.entity(
                    forEntityName: "CategoryEntity",
                    in: context
                ) else {
                    return
                }

                for category in DefaultCategories.all {
                    let canonicalName = DefaultCategories.canonicalKey(for: category.name)
                    let matches = existingCategories.filter {
                        guard let name = $0.name else { return false }
                        return DefaultCategories.canonicalKey(for: name) == canonicalName
                    }

                    let primary: CategoryEntity
                    if let existing = matches.max(by: {
                        ($0.spendings?.count ?? 0) < ($1.spendings?.count ?? 0)
                    }) {
                        primary = existing
                    } else {
                        let entity = CategoryEntity(entity: description, insertInto: context)
                        entity.id = UUID()
                        entity.isFavorite = false
                        existingCategories.append(entity)
                        primary = entity
                    }

                    primary.name = category.name
                    primary.color = primary.color ?? category.color
                    primary.isIncome = category.isIncome
                    primary.isShadowed = false

                    for duplicate in matches where duplicate.objectID != primary.objectID {
                        let spendings = duplicate.spendings?.allObjects as? [SpendingEntity] ?? []
                        for spending in spendings {
                            spending.category = primary
                        }
                        context.delete(duplicate)
                    }
                }

                if context.hasChanges {
                    try context.save()
                }

                UserDefaults.standard.set(
                    Self.defaultCategoriesSeedVersion,
                    forKey: Self.defaultCategoriesSeedKey
                )
            } catch {
                ErrorType(error: error).publish(file: #fileID, function: #function)
            }
        }
    }
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                context.rollback()
                ErrorType(error: error).publish(file: #fileID, function: #function)
            }
        }
    }
    
    func deleteSpending(with objectID: NSManagedObjectID) {
        guard let object = try? backgroundContext.existingObject(with: objectID) else {
            print("Failed")
            return
        }
        
        backgroundContext.delete(object)
        do {
            try backgroundContext.save()
        } catch {
            ErrorType(error: error).publish()
            backgroundContext.rollback()
        }
    }
}
