import Foundation
import GRDB

private func nowMillis() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

// ===== Customer (summary cache; nested JSON columns stay "[]" until Phase 4) =====
struct CustomerRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "customers"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .replace, update: .replace)

    var id: String
    var name: String?
    var company: String?
    var street: String?
    var plz: String?
    var city: String?
    var country: String?
    var phone: String?
    var email: String?
    var lat: Double?
    var lon: Double?
    var notes: String?
    var visitsPerYear: Int
    var lastVisited: String?
    var created: String?
    var wawiKAdresse: Int?
    var avgVisitMinutes: Double?
    var avgDriveMinutes: Double?
    var visitDurationCount: Int
    var driveDurationCount: Int
    var storeType: String
    var assortmentPotential: String
    var addressesJson: String
    var contactsJson: String
    var sortimentJson: String
    var suppliersJson: String
    var sortimentCategoriesJson: String
    var modifiedAt: Int64
}

extension Customer {
    func toRecord() -> CustomerRecord {
        CustomerRecord(
            id: id, name: name, company: company, street: street, plz: plz, city: city,
            country: country, phone: phone, email: email, lat: lat, lon: lon, notes: notes,
            visitsPerYear: visitsPerYear ?? 0, lastVisited: lastVisited, created: created,
            wawiKAdresse: wawiKAdresse, avgVisitMinutes: avgVisitMinutes, avgDriveMinutes: avgDriveMinutes,
            visitDurationCount: visitDurationCount ?? 0, driveDurationCount: driveDurationCount ?? 0,
            storeType: storeType ?? "", assortmentPotential: assortmentPotential ?? "",
            addressesJson: "[]", contactsJson: "[]", sortimentJson: "[]",
            suppliersJson: "[]", sortimentCategoriesJson: "{}", modifiedAt: nowMillis())
    }
}

extension CustomerRecord {
    /// Summary-only, matching Android CustomerEntity.toCustomer() — nested left empty.
    func toCustomer() -> Customer {
        Customer(id: id, name: name, company: company, street: street, plz: plz, city: city,
                 country: country, phone: phone, email: email, lat: lat, lon: lon, notes: notes,
                 visitsPerYear: visitsPerYear, lastVisited: lastVisited, created: created,
                 wawiKAdresse: wawiKAdresse, avgVisitMinutes: avgVisitMinutes, avgDriveMinutes: avgDriveMinutes,
                 visitDurationCount: visitDurationCount, driveDurationCount: driveDurationCount,
                 storeType: storeType, assortmentPotential: assortmentPotential)
    }
}

// ===== Visit (summary cache) =====
struct VisitRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "visits"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .replace, update: .replace)

    var id: String
    var routeId: String
    var customerId: String
    var date: String
    var status: String
    var notes: String
    var timeStart: String
    var timeEnd: String
    var arrivedAt: String?
    var departedAt: String?
    var customerName: String?
    var customerCompany: String?
    var customerStreet: String?
    var customerPlz: String?
    var customerCity: String?
    var contactId: String
    var sortimentCheckJson: String
    var ausgabeJson: String
    var modifiedAt: Int64
}

extension Visit {
    /// Records need a stable id; visits without one are skipped by the repository.
    func toRecord() -> VisitRecord? {
        guard let id = id, !id.isEmpty else { return nil }
        return VisitRecord(
            id: id, routeId: routeId ?? "", customerId: customerId ?? "", date: date ?? "",
            status: status ?? "planned", notes: notes ?? "", timeStart: timeStart ?? "",
            timeEnd: timeEnd ?? "", arrivedAt: arrivedAt, departedAt: departedAt,
            customerName: customerName, customerCompany: customerCompany, customerStreet: customerStreet,
            customerPlz: customerPlz, customerCity: customerCity, contactId: contactId ?? "",
            sortimentCheckJson: "[]", ausgabeJson: "[]", modifiedAt: nowMillis())
    }
}

extension VisitRecord {
    func toVisit() -> Visit {
        Visit(id: id, customerId: customerId, routeId: routeId, date: date,
              timeStart: timeStart, timeEnd: timeEnd, arrivedAt: arrivedAt, departedAt: departedAt,
              notes: notes, contactId: contactId, status: status,
              customerName: customerName, customerCompany: customerCompany,
              customerCity: customerCity, customerStreet: customerStreet, customerPlz: customerPlz)
    }
}

// ===== Sync queue (for Phase 4 offline writes) =====
struct SyncQueueRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "sync_queue"
    var id: Int64?
    var entityType: String
    var entityId: String
    var action: String
    var payloadJson: String
    var createdAt: Int64

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
