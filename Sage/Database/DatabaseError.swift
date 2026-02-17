import Foundation

enum DatabaseError: Error, LocalizedError, Equatable {
    case connectionFailed(String)
    case queryFailed(String)
    case insertFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case notFound
    case migrationFailed(Int, String)
    case encodingFailed(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg):   return "Database connection failed: \(msg)"
        case .queryFailed(let msg):        return "Query failed: \(msg)"
        case .insertFailed(let msg):       return "Insert failed: \(msg)"
        case .updateFailed(let msg):       return "Update failed: \(msg)"
        case .deleteFailed(let msg):       return "Delete failed: \(msg)"
        case .notFound:                    return "Record not found"
        case .migrationFailed(let v, let msg): return "Migration v\(v) failed: \(msg)"
        case .encodingFailed(let field):   return "Failed to encode \(field)"
        case .decodingFailed(let field):   return "Failed to decode \(field)"
        }
    }
}
