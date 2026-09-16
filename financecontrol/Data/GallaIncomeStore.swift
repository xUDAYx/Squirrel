//
//  GallaIncomeStore.swift
//  Squirrel
//
//  A small, versioned income ledger that can be introduced without changing
//  the existing SpendingEntity Core Data model. The store is deliberately
//  backed by UserDefaults so older installs can keep their expense database
//  untouched while the income model is iterated independently.
//

import Foundation

/// A persisted income entry.
///
/// The decoding implementation is intentionally forgiving. It supplies
/// defaults for fields added after the first version and accepts a couple of
/// legacy field names, so adding fields later does not make existing records
/// unreadable.
public struct GallaIncomeRecord: Codable, Hashable, Identifiable {
    public let id: UUID
    public var amount: Double
    public var currency: String
    public var date: Date
    public var category: String
    public var place: String?
    public var note: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        amount: Double,
        currency: String = Locale.current.currencyCode ?? "USD",
        date: Date = Date(),
        category: String = "Other",
        place: String? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.date = date
        self.category = category
        self.place = place
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case amount
        case currency
        case date
        case category
        case categoryName
        case place
        case note
        case description
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallbackDate = Date()

        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        amount = Self.decodeDouble(container, keys: [.amount]) ?? 0
        currency = Self.decodeString(container, keys: [.currency]) ?? Locale.current.currencyCode ?? "USD"
        date = Self.decodeDate(container, keys: [.date]) ?? fallbackDate
        category = Self.decodeString(container, keys: [.category, .categoryName]) ?? "Other"
        place = Self.decodeString(container, keys: [.place])
        note = Self.decodeString(container, keys: [.note, .description])
        createdAt = Self.decodeDate(container, keys: [.createdAt]) ?? date
        updatedAt = Self.decodeDate(container, keys: [.updatedAt]) ?? createdAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(amount, forKey: .amount)
        try container.encode(currency, forKey: .currency)
        try container.encode(date, forKey: .date)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(place, forKey: .place)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    private static func decodeString(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> String? {
        for key in keys {
            if let value = try? container.decode(String.self, forKey: key) {
                return value
            }
        }
        return nil
    }

    private static func decodeDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Double? {
        for key in keys {
            if let value = try? container.decode(Double.self, forKey: key) {
                return value
            }

            if let value = try? container.decode(String.self, forKey: key),
               let number = Double(value) {
                return number
            }
        }
        return nil
    }

    private static func decodeDate(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Date? {
        for key in keys {
            if let value = try? container.decode(Date.self, forKey: key) {
                return value
            }

            if let value = try? container.decode(String.self, forKey: key) {
                if let isoDate = ISO8601DateFormatter().date(from: value) {
                    return isoDate
                }

                if let timestamp = Double(value) {
                    return Date(timeIntervalSince1970: timestamp)
                }
            }

            if let timestamp = try? container.decode(Double.self, forKey: key) {
                return Date(timeIntervalSince1970: timestamp)
            }
        }
        return nil
    }
}

/// A bounded JSON-backed income ledger.
///
/// `GallaIncomeStore` has no dependency on Core Data and can be used alongside
/// the existing expense model. Use `GallaIncomeStore.shared` in the app, or
/// inject a store initialized with a suite-specific `UserDefaults` in tests.
public final class GallaIncomeStore {
    public static let shared = GallaIncomeStore()

    /// Version the key so a future schema can migrate deliberately instead of
    /// trying to decode an incompatible payload in place.
    public static let defaultStorageKey = "galla.income.records.v1"

    public static let didChangeNotification = Notification.Name("GallaIncomeStore.didChange")
    public static let changeKindUserInfoKey = "GallaIncomeStore.changeKind"
    public static let recordUserInfoKey = "GallaIncomeStore.record"
    public static let recordIDUserInfoKey = "GallaIncomeStore.recordID"

    public enum ChangeKind: String {
        case added
        case updated
        case deleted
        case removedAll
    }

    /// Limits the JSON payload kept in UserDefaults. The newest records by
    /// date are retained when the bound is exceeded.
    public let maximumRecordCount: Int

    private let defaults: UserDefaults
    private let storageKey: String
    private let notificationCenter: NotificationCenter
    private let lock = NSLock()

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = GallaIncomeStore.defaultStorageKey,
        maximumRecordCount: Int = 1_000,
        notificationCenter: NotificationCenter = .default
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.maximumRecordCount = max(1, maximumRecordCount)
        self.notificationCenter = notificationCenter
    }

    /// Returns records newest-first. The result is always bounded by
    /// `maximumRecordCount`.
    public func list() -> [GallaIncomeRecord] {
        lock.lock()
        defer { lock.unlock() }
        return boundedAndSorted(load())
    }

    /// Alias useful for call sites that prefer a property-like spelling.
    public var records: [GallaIncomeRecord] {
        list()
    }

    /// Adds a record. IDs are unique; adding an existing ID behaves as an
    /// upsert and emits an `.updated` notification.
    @discardableResult
    public func add(_ record: GallaIncomeRecord) -> GallaIncomeRecord {
        var changeKind: ChangeKind = .added

        lock.lock()
        var values = load()
        if let index = values.firstIndex(where: { $0.id == record.id }) {
            values[index] = record
            changeKind = .updated
        } else {
            values.append(record)
        }
        let boundedValues = boundedAndSorted(values)
        save(boundedValues)
        lock.unlock()

        post(changeKind, record: record)
        return record
    }

    /// Convenience constructor for the common add path.
    @discardableResult
    public func add(
        amount: Double,
        currency: String = Locale.current.currencyCode ?? "USD",
        date: Date = Date(),
        category: String = "Other",
        place: String? = nil,
        note: String? = nil
    ) -> GallaIncomeRecord {
        let record = GallaIncomeRecord(
            amount: amount,
            currency: currency,
            date: date,
            category: category,
            place: place,
            note: note
        )
        return add(record)
    }

    /// Updates an existing record and refreshes its `updatedAt` timestamp.
    @discardableResult
    public func update(_ record: GallaIncomeRecord) -> GallaIncomeRecord? {
        var updatedRecord: GallaIncomeRecord?

        lock.lock()
        var values = load()
        if let index = values.firstIndex(where: { $0.id == record.id }) {
            var value = record
            value.updatedAt = Date()
            values[index] = value
            save(boundedAndSorted(values))
            updatedRecord = value
        }
        lock.unlock()

        if let updatedRecord {
            post(.updated, record: updatedRecord)
        }
        return updatedRecord
    }

    /// Updates an existing record in place and refreshes its `updatedAt`
    /// timestamp. Returns `nil` when the ID is not present.
    @discardableResult
    public func update(
        id: UUID,
        _ mutate: (inout GallaIncomeRecord) -> Void
    ) -> GallaIncomeRecord? {
        var updatedRecord: GallaIncomeRecord?

        lock.lock()
        var values = load()
        if let index = values.firstIndex(where: { $0.id == id }) {
            var value = values[index]
            mutate(&value)
            value.updatedAt = Date()
            values[index] = value
            save(boundedAndSorted(values))
            updatedRecord = value
        }
        lock.unlock()

        if let updatedRecord {
            post(.updated, record: updatedRecord)
        }
        return updatedRecord
    }

    /// Deletes a record by ID and returns whether a record was removed.
    @discardableResult
    public func delete(id: UUID) -> Bool {
        var removedRecord: GallaIncomeRecord?

        lock.lock()
        var values = load()
        if let index = values.firstIndex(where: { $0.id == id }) {
            removedRecord = values.remove(at: index)
            save(boundedAndSorted(values))
        }
        lock.unlock()

        if let removedRecord {
            post(.deleted, record: removedRecord)
            return true
        }
        return false
    }

    /// Deletes a record and returns whether a record was removed.
    @discardableResult
    public func delete(_ record: GallaIncomeRecord) -> Bool {
        delete(id: record.id)
    }

    /// Removes every persisted income record.
    @discardableResult
    public func removeAll() -> Bool {
        lock.lock()
        let hadValues = !load().isEmpty
        defaults.removeObject(forKey: storageKey)
        lock.unlock()

        if hadValues {
            post(.removedAll, record: nil)
        }
        return hadValues
    }

    /// Registers a listener for changes made through this store instance.
    /// Call `removeObserver(_:)` when the owner is deallocated.
    @discardableResult
    public func observeChanges(
        queue: OperationQueue? = .main,
        using block: @escaping (Notification) -> Void
    ) -> NSObjectProtocol {
        notificationCenter.addObserver(
            forName: Self.didChangeNotification,
            object: self,
            queue: queue,
            using: block
        )
    }

    public func removeObserver(_ observer: NSObjectProtocol) {
        notificationCenter.removeObserver(observer)
    }

    private func load() -> [GallaIncomeRecord] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let values = try? decoder.decode([GallaIncomeRecord].self, from: data) {
            return values
        }

        // Older payloads may have used Foundation's default Date strategy.
        let legacyDecoder = JSONDecoder()
        legacyDecoder.dateDecodingStrategy = .deferredToDate
        return (try? legacyDecoder.decode([GallaIncomeRecord].self, from: data)) ?? []
    }

    private func save(_ values: [GallaIncomeRecord]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(values) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    private func boundedAndSorted(_ values: [GallaIncomeRecord]) -> [GallaIncomeRecord] {
        Array(
            values
                .sorted {
                    if $0.date != $1.date {
                        return $0.date > $1.date
                    }
                    return $0.updatedAt > $1.updatedAt
                }
                .prefix(maximumRecordCount)
        )
    }

    private func post(_ changeKind: ChangeKind, record: GallaIncomeRecord?) {
        var userInfo: [AnyHashable: Any] = [
            Self.changeKindUserInfoKey: changeKind.rawValue
        ]

        if let record {
            userInfo[Self.recordUserInfoKey] = record
            userInfo[Self.recordIDUserInfoKey] = record.id.uuidString
        }

        notificationCenter.post(
            name: Self.didChangeNotification,
            object: self,
            userInfo: userInfo
        )
    }
}
