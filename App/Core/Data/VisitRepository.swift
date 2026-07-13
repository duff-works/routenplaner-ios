import Foundation
import GRDB

/// API → cache → fallback, mirroring Android VisitRepository (list path).
@MainActor
final class VisitRepository {
    private let api: APIClient
    private let database: AppDatabase

    init(api: APIClient, db: AppDatabase) {
        self.api = api
        self.database = db
    }

    func list() async -> Result<[Visit], Error> {
        do {
            let visits = try await api.getVisits()
            try await database.writer.write { db in
                try VisitRecord.deleteAll(db)
                for v in visits {
                    if let record = v.toRecord() { try record.insert(db) }
                }
            }
            return .success(visits)
        } catch {
            return await fallback()
        }
    }

    private func fallback() async -> Result<[Visit], Error> {
        do {
            let rows: [VisitRecord] = try await database.reader.read { db in
                try VisitRecord.order(sql: "date DESC").fetchAll(db)
            }
            return .success(rows.map { $0.toVisit() })
        } catch {
            return .failure(error)
        }
    }

    func cachedCount() async -> Int {
        (try? await database.reader.read { db in try VisitRecord.fetchCount(db) }) ?? 0
    }
}
