//
//  OtaVersionHelper.swift
//  IoTCoreSample
//
//  Pure, dependency-free helpers for the sample app's OTA "pick version from
//  cloud" flow. These functions contain NO SDK / UI dependencies (Foundation
//  only) so they can be unit-tested in isolation (target: IotCoreIOSTests).
//
//  Cloud version APIs used by the flow (called via `callApiGet`):
//    1. GET /v1/version/check/{modelId}/{revision}
//         -> JSON array of OtaVersionItem
//    2. GET /v1/version/ota/{modelId}/{revision}/{type}/{version}
//         -> JSON object { "path": "<firmware download url>" }
//

import Foundation

/// One firmware build entry returned by `/v1/version/check/{modelId}/{revision}`.
struct OtaVersionItem: Equatable, Identifiable {
    /// Stable identity for SwiftUI lists (version + type uniquely identify a build).
    var id: String { "\(version)#\(type)" }

    let modelId: String
    let revision: String
    let version: String
    let changeLog: String
    /// Raw build channel as returned by the cloud, e.g. "development" | "release".
    let type: String

    /// `true` when this build belongs to the "release" channel.
    var isRelease: Bool { type.lowercased() == "release" }
    /// `true` when this build belongs to the "development" channel.
    var isDevelopment: Bool { type.lowercased() == "development" }
}

/// Pure helpers for the OTA version picker. Stateless namespace (no instances).
enum OtaVersionHelper {

    // MARK: - Revision derivation

    /// Derives the `revision` path segment from a full software version string.
    ///
    /// The revision is the LAST dot-separated component of the version, e.g.
    /// `"1.0.2.1"` -> `"1"`. Trailing/leading whitespace is trimmed.
    ///
    /// - Returns: the last component, or `nil` if the input is empty / has no
    ///   usable last component.
    static func deriveRevision(fromVersion version: String) -> String? {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let last = trimmed.components(separatedBy: ".").last else { return nil }
        let lastTrimmed = last.trimmingCharacters(in: .whitespaces)
        return lastTrimmed.isEmpty ? nil : lastTrimmed
    }

    // MARK: - version/check parsing

    /// Parses the JSON array returned by `/v1/version/check/{modelId}/{revision}`
    /// into typed `OtaVersionItem`s.
    ///
    /// Malformed / unexpected JSON never throws to the caller as a crash; on a
    /// shape mismatch the function throws `OtaVersionError.invalidResponse`.
    /// Individual array entries missing required fields are skipped (defensive).
    ///
    /// - Parameter json: the raw response string from `callApiGet`.
    /// - Returns: parsed items (possibly empty if the array was empty).
    static func parseVersionList(fromJson json: String) throws -> [OtaVersionItem] {
        let data = Data(json.utf8)
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw OtaVersionError.invalidResponse
        }
        guard let array = object as? [[String: Any]] else {
            // Some backends wrap the array under a key; tolerate `{ "data": [...] }`.
            if let dict = object as? [String: Any],
               let nested = dict["data"] as? [[String: Any]] {
                return parseItems(from: nested)
            }
            throw OtaVersionError.invalidResponse
        }
        return parseItems(from: array)
    }

    private static func parseItems(from array: [[String: Any]]) -> [OtaVersionItem] {
        array.compactMap { entry -> OtaVersionItem? in
            guard let version = stringValue(entry["version"]), !version.isEmpty else {
                return nil
            }
            let type = stringValue(entry["type"]) ?? ""
            let modelId = stringValue(entry["modelId"]) ?? ""
            let revision = stringValue(entry["revision"]) ?? ""
            let changeLog = stringValue(entry["changeLog"]) ?? ""
            return OtaVersionItem(
                modelId: modelId,
                revision: revision,
                version: version,
                changeLog: changeLog,
                type: type
            )
        }
    }

    /// Coerces a JSON value into a String (handles String / NSNumber).
    private static func stringValue(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        return nil
    }

    // MARK: - version/ota parsing

    /// Parses the JSON object `{ "path": "<url>" }` returned by
    /// `/v1/version/ota/{modelId}/{revision}/{type}/{version}`.
    ///
    /// - Returns: the non-empty `path` string.
    /// - Throws: `OtaVersionError.invalidResponse` if JSON is malformed or
    ///   `OtaVersionError.missingPath` if `path` is absent/empty.
    static func parseOtaPath(fromJson json: String) throws -> String {
        let data = Data(json.utf8)
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw OtaVersionError.invalidResponse
        }
        guard let dict = object as? [String: Any] else {
            throw OtaVersionError.invalidResponse
        }
        guard let path = stringValue(dict["path"]),
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OtaVersionError.missingPath
        }
        return path
    }

    // MARK: - Path builders

    /// Builds the path for `/version/check/{modelId}/{revision}`.
    /// `modelId` is used verbatim (it may be a hex string, e.g. `0002F80808040003`).
    /// Note: the configured API host already includes the `/v1` segment, so it
    /// is NOT added here (adding it would yield a wrong `/v1/v1/...` URL).
    static func versionCheckPath(modelId: String, revision: String) -> String {
        return "/version/check/\(modelId)/\(revision)"
    }

    /// Builds the path for `/version/ota/{modelId}/{revision}/{type}/{version}`.
    /// Note: the configured API host already includes the `/v1` segment, so it
    /// is NOT added here.
    static func versionOtaPath(modelId: String, revision: String, type: String, version: String) -> String {
        return "/version/ota/\(modelId)/\(revision)/\(type)/\(version)"
    }

    // MARK: - versionCode derivation

    /// Converts a version string (e.g. `"1.0.3.1"` or `"1,0,3,1"`) into the
    /// `[UInt8]` versionCode expected by `updateDeviceSoftware`.
    ///
    /// Components are split on `.` or `,`; whitespace is trimmed; components that
    /// don't fit in a `UInt8` (0..255) are dropped (defensive, never crashes).
    static func versionCode(fromVersion version: String) -> [UInt8] {
        return version
            .split(whereSeparator: { $0 == "." || $0 == "," })
            .compactMap { UInt8($0.trimmingCharacters(in: .whitespaces)) }
    }

    // MARK: - Numeric version comparison

    /// Compares two dot-separated numeric versions component-by-component.
    ///
    /// Non-numeric components are treated as 0. Shorter versions are
    /// zero-padded, so `"1.0.3"` == `"1.0.3.0"`.
    ///
    /// - Returns: `.orderedAscending` if `lhs < rhs`, `.orderedDescending` if
    ///   `lhs > rhs`, `.orderedSame` if equal.
    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = numericComponents(lhs)
        let rhsParts = numericComponents(rhs)
        let count = max(lhsParts.count, rhsParts.count)
        for index in 0..<count {
            let l = index < lhsParts.count ? lhsParts[index] : 0
            let r = index < rhsParts.count ? rhsParts[index] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }

    /// `true` when `candidate` is numerically newer than `current`.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        return compareVersions(candidate, current) == .orderedDescending
    }

    private static func numericComponents(_ version: String) -> [Int] {
        version
            .split(whereSeparator: { $0 == "." || $0 == "," })
            .map { Int($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
    }
}

/// Typed errors for the OTA version picker flow.
enum OtaVersionError: Error, Equatable {
    /// Response body could not be parsed as the expected JSON shape.
    case invalidResponse
    /// `/version/ota` response did not contain a usable `path`.
    case missingPath

    var localizedMessage: String {
        switch self {
        case .invalidResponse: return "Unexpected response from cloud version API."
        case .missingPath: return "Cloud did not return a firmware download path."
        }
    }
}
