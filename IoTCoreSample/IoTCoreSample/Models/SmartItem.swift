//
//  SmartItem.swift
//  IoTCoreSample
//
//  Lightweight Codable model for `GET smart/get` response items.
//  See: docs/04-LEGACY-NOTES/smart/get-all-smart.md
//

import Foundation

enum SmartType: Int, CaseIterable, Identifiable {
    case scenario   = 0
    case schedule   = 1
    case automation = 2
    case unknown    = -1

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .scenario:   return "Scenario"
        case .schedule:   return "Schedule"
        case .automation: return "Automation"
        case .unknown:    return "Unknown"
        }
    }

    /// Short badge text used in list cells.
    var badge: String {
        switch self {
        case .scenario:   return "SCN"
        case .schedule:   return "SCH"
        case .automation: return "AUT"
        case .unknown:    return "?"
        }
    }
}

struct SmartItem: Codable, Identifiable, Hashable {
    let smid: Int?
    let uuid: String
    let label: String?
    let locId: String?
    let type: Int?
    let subType: Int?
    let userId: String?
    let createdAt: String?
    let updatedAt: String?
    let fav: Bool?

    var id: String { uuid }

    var smartType: SmartType {
        guard let type = type, let t = SmartType(rawValue: type) else {
            return .unknown
        }
        return t
    }

    var displayLabel: String {
        if let l = label, !l.trimmingCharacters(in: .whitespaces).isEmpty {
            return l
        }
        return "(no label)"
    }

    /// First 8 chars of uuid for compact display.
    var shortUuid: String {
        String(uuid.prefix(8))
    }

    /// Best-effort short formatted createdAt.
    var displayCreatedAt: String {
        guard let createdAt = createdAt else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt) {
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .short
            return f.string(from: date)
        }
        return createdAt
    }
}
