//
//  LogExpenseIntent.swift
//  Squirrel
//
//  Siri Shortcuts support — log an expense without opening the app.
//

import AppIntents
import CoreData

@available(iOS 16.0, *)
struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description: IntentDescription = "Quickly add an expense to Galla"
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Amount",
        requestValueDialog: "Please enter your expense amount"
    )
    var amount: Double

    @Parameter(
        title: "Category",
        requestValueDialog: "Choose a category"
    )
    var category: CategoryAppEntity

    @Parameter(title: "Currency", default: nil)
    var currencyCode: String?

    @Parameter(title: "Place", default: nil)
    var place: String?

    @Parameter(
        title: "Description",
        description: "An optional note about this expense",
        default: nil
    )
    var comment: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let resolvedCurrency = currencyCode ?? UserDefaults.standard.string(forKey: UDKey.defaultCurrency.rawValue) ?? Locale.current.currencyCode ?? "USD"

        let rates = UserDefaults.standard.getRates() ?? Rates.fallback.rates
        let rate = rates[resolvedCurrency] ?? 1.0
        let amountUSD = resolvedCurrency == "USD" ? amount : amount / rate

        let spending = SpendingEntityLocal(
            amount: amount,
            amountUSD: amountUSD,
            currency: resolvedCurrency,
            date: Date(),
            place: (place ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            categoryId: category.id,
            comment: (comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        )

        try await saveSpending(spending)

        let formatted = formatAmount(amount, currency: resolvedCurrency)
        return .result(dialog: "\(formatted) added under \(category.name)")
    }

    private func formatAmount(_ value: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = .current
        return formatter.string(from: value as NSNumber) ?? "\(value) \(currency)"
    }

    private func saveSpending(_ spending: SpendingEntityLocal) async throws {
        let context = DataManager.shared.context
        try await context.perform {
            guard let description = NSEntityDescription.entity(forEntityName: "SpendingEntity", in: context) else {
                throw LogExpenseError.failedToGetEntityDescription
            }

            let request = CategoryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", spending.categoryId as CVarArg)
            guard let categoryEntity = try context.fetch(request).first else {
                throw LogExpenseError.categoryNotFound
            }

            let entity = SpendingEntity(entity: description, insertInto: context)
            entity.id = UUID()
            entity.amount = spending.amount
            entity.amountUSD = spending.amountUSD
            entity.currency = spending.currency
            entity.date = spending.date
            entity.timeZoneIdentifier = TimeZone.autoupdatingCurrent.identifier
            entity.place = spending.place
            entity.comment = spending.comment
            categoryEntity.addToSpendings(entity)

            try context.save()
        }
    }
}

@available(iOS 16.0, *)
enum LogExpenseError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case failedToGetEntityDescription
    case categoryNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .failedToGetEntityDescription:
            return "Failed to access the data store"
        case .categoryNotFound:
            return "Category not found"
        }
    }
}
