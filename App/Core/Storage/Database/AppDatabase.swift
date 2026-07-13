import Foundation
import GRDB

/// Single shared SQLite store — iOS analog of Android's RoutePlannerDatabase.
/// WAL `DatabasePool` so a background-sync write doesn't block a foreground read.
/// The DB file uses `.completeUntilFirstUserAuthentication` protection so a locked-device
/// BGTask can open it (matches the Keychain token's kSecAttrAccessibleAfterFirstUnlock).
final class AppDatabase {

    static let shared: AppDatabase = {
        do { return try AppDatabase() }
        catch { fatalError("GRDB init failed: \(error)") }
    }()

    let writer: DatabasePool
    var reader: DatabaseReader { writer }

    init() throws {
        let fm = FileManager.default
        let dir = try fm.url(for: .applicationSupportDirectory,
                             in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Database", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("routenplaner.sqlite")

        self.writer = try DatabasePool(path: dbURL.path)
        Self.setFileProtection(dir: dir)
        try Self.migrator.migrate(writer)
    }

    private static func setFileProtection(dir: URL) {
        let fm = FileManager.default
        for f in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? [] {
            try? fm.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: dir.appendingPathComponent(f).path)
        }
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1") { db in
            try db.create(table: "customers") { t in
                t.primaryKey("id", .text)
                t.column("name", .text)
                t.column("company", .text)
                t.column("street", .text)
                t.column("plz", .text)
                t.column("city", .text)
                t.column("country", .text)
                t.column("phone", .text)
                t.column("email", .text)
                t.column("lat", .double)
                t.column("lon", .double)
                t.column("notes", .text)
                t.column("visitsPerYear", .integer).notNull().defaults(to: 0)
                t.column("lastVisited", .text)
                t.column("created", .text)
                t.column("wawiKAdresse", .integer)
                t.column("avgVisitMinutes", .double)
                t.column("avgDriveMinutes", .double)
                t.column("visitDurationCount", .integer).notNull().defaults(to: 0)
                t.column("driveDurationCount", .integer).notNull().defaults(to: 0)
                t.column("storeType", .text).notNull().defaults(to: "")
                t.column("assortmentPotential", .text).notNull().defaults(to: "")
                t.column("addressesJson", .text).notNull().defaults(to: "[]")
                t.column("contactsJson", .text).notNull().defaults(to: "[]")
                t.column("sortimentJson", .text).notNull().defaults(to: "[]")
                t.column("suppliersJson", .text).notNull().defaults(to: "[]")
                t.column("sortimentCategoriesJson", .text).notNull().defaults(to: "{}")
                t.column("modifiedAt", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "visits") { t in
                t.primaryKey("id", .text)
                t.column("routeId", .text).notNull().defaults(to: "")
                t.column("customerId", .text).notNull().defaults(to: "")
                t.column("date", .text).notNull().defaults(to: "")
                t.column("status", .text).notNull().defaults(to: "planned")
                t.column("notes", .text).notNull().defaults(to: "")
                t.column("timeStart", .text).notNull().defaults(to: "")
                t.column("timeEnd", .text).notNull().defaults(to: "")
                t.column("arrivedAt", .text)
                t.column("departedAt", .text)
                t.column("customerName", .text)
                t.column("customerCompany", .text)
                t.column("customerStreet", .text)
                t.column("customerPlz", .text)
                t.column("customerCity", .text)
                t.column("contactId", .text).notNull().defaults(to: "")
                t.column("sortimentCheckJson", .text).notNull().defaults(to: "[]")
                t.column("ausgabeJson", .text).notNull().defaults(to: "[]")
                t.column("modifiedAt", .integer).notNull().defaults(to: 0)
            }
            try db.create(index: "idx_visits_customerId", on: "visits", columns: ["customerId"])
            try db.create(index: "idx_visits_routeId", on: "visits", columns: ["routeId"])

            try db.create(table: "routes") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull().defaults(to: "")
                t.column("date", .text).notNull().defaults(to: "")
                t.column("status", .text).notNull().defaults(to: "planned")
                t.column("startAddress", .text)
                t.column("endAddress", .text)
                t.column("created", .text)
                t.column("stopsJson", .text).notNull().defaults(to: "[]")
                t.column("directionsJson", .text)
                t.column("modifiedAt", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "sync_queue") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("entityType", .text).notNull()
                t.column("entityId", .text).notNull()
                t.column("action", .text).notNull()
                t.column("payloadJson", .text).notNull().defaults(to: "{}")
                t.column("createdAt", .integer).notNull().defaults(to: 0)
            }
        }
        return migrator
    }
}
