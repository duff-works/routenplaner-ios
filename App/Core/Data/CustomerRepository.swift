import Foundation
import GRDB

/// API → cache → fallback, mirroring Android CustomerRepository.
/// Full-list loads replace the cache; searches are not cached (Android parity).
@MainActor
final class CustomerRepository {
    private let api: APIClient
    private let database: AppDatabase

    init(api: APIClient, db: AppDatabase) {
        self.api = api
        self.database = db
    }

    func list(search: String? = nil) async -> Result<[Customer], Error> {
        do {
            let customers = try await api.getCustomers(search: search)
            if (search ?? "").isEmpty {
                try await database.writer.write { db in
                    try CustomerRecord.deleteAll(db)
                    for c in customers { try c.toRecord().insert(db) }
                }
            }
            return .success(customers)
        } catch {
            return await fallback(search: search)
        }
    }

    private func fallback(search: String?) async -> Result<[Customer], Error> {
        do {
            let rows: [CustomerRecord] = try await database.reader.read { db in
                if let q = search, !q.isEmpty {
                    let like = "%\(q)%"
                    return try CustomerRecord
                        .filter(sql: "name LIKE ? OR company LIKE ? OR city LIKE ? OR plz LIKE ?",
                                arguments: [like, like, like, like])
                        .fetchAll(db)
                }
                return try CustomerRecord.order(sql: "COALESCE(company, name) ASC").fetchAll(db)
            }
            return .success(rows.map { $0.toCustomer() })
        } catch {
            return .failure(error)
        }
    }

    func cachedCount() async -> Int {
        (try? await database.reader.read { db in try CustomerRecord.fetchCount(db) }) ?? 0
    }
}
