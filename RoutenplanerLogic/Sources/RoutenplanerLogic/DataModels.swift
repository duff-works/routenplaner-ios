import Foundation

// Phase 3 caches SUMMARY scalars only (matching Android Room's toCustomer()/toVisit(),
// which serialize nested collections to JSON on write but return summary-only on read).
// Every field is optional so a missing/null key in the API response never fails the whole
// decode; the record mappers coalesce to defaults. Nested typed models + hydration are Phase 4.
// Decoded with makeAPIJSONDecoder() (.convertFromSnakeCase); unknown keys are ignored.

public struct Customer: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String?
    public var company: String?
    public var street: String?
    public var plz: String?
    public var city: String?
    public var country: String?
    public var phone: String?
    public var email: String?
    public var lat: Double?
    public var lon: Double?
    public var notes: String?
    public var visitsPerYear: Int?
    public var lastVisited: String?
    public var created: String?
    public var wawiKAdresse: Int?
    public var avgVisitMinutes: Double?
    public var avgDriveMinutes: Double?
    public var visitDurationCount: Int?
    public var driveDurationCount: Int?
    public var storeType: String?
    public var assortmentPotential: String?
    // Nested collections (present on GET /kunden/{id}; optional so summary loads still decode).
    public var addresses: [CustomerAddress]? = nil
    public var contacts: [Contact]? = nil
    public var sortiment: [SortimentItem]? = nil
    public var suppliers: [CustomerSupplier]? = nil
    public var sortimentCategories: [String: Bool]? = nil

    public var displayName: String { (company ?? "").isEmpty ? (name ?? "") : (company ?? "") }
}

public struct CustomerAddress: Codable, Equatable {
    public var label: String?
    public var street: String?
    public var plz: String?
    public var city: String?
    public var country: String?
    public var lat: Double?
    public var lon: Double?
    public var parkingLat: Double?
    public var parkingLon: Double?
    public var parkingNotes: String?
}

public struct Contact: Codable, Equatable, Identifiable {
    public var id: String?
    public var name: String?
    public var role: String?
    public var phone: String?
    public var email: String?
    public var isOrderer: Bool?
    public var isDecisionMaker: Bool?
    public var isPrimary: Bool?
    public var notes: String?
    public var rating: Int?
}

public struct SortimentItem: Codable, Equatable {
    public var artNr: String?
    public var name: String?
    public var qty: Int?
}

public struct CustomerSupplier: Codable, Equatable {
    public var name: String?
    public var satisfaction: Int?
}

public struct CustomerListResponse: Codable {
    public var customers: [Customer]
}

public struct Visit: Codable, Equatable, Identifiable {
    public var id: String?
    public var customerId: String?
    public var routeId: String?
    public var date: String?
    public var timeStart: String?
    public var timeEnd: String?
    public var arrivedAt: String?
    public var departedAt: String?
    public var notes: String?
    public var contactId: String?
    public var status: String?
    public var customerName: String?
    public var customerCompany: String?
    public var customerCity: String?
    public var customerStreet: String?
    public var customerPlz: String?
}

public struct VisitListResponse: Codable {
    public var visits: [Visit]
    public var total: Int?
}
