//
//  Location.swift
//  IoTCoreSample
//
//  Location model for user locations from API
//

import Foundation

// MARK: - Location Model

struct Location: Identifiable, Codable, Equatable {
    let uuid: String
    let label: String
    let desc: String?
    let userId: String?
    let extraInfo: LocationExtraInfo?
    let createdAt: String?
    let updatedAt: String?

    var id: String { uuid }

    // MARK: - Display Helpers

    var displayName: String {
        label.isEmpty ? "Unnamed Location" : label
    }

    var description: String {
        desc ?? ""
    }

    var meshUuid: String? {
        extraInfo?.bleMesh?.uuid
    }

    var meshNetworkKeys: [String]? {
        extraInfo?.bleMesh?.networkKeys
    }

    var meshAppKeys: [String]? {
        extraInfo?.bleMesh?.appKeys
    }

    var meshAddress: Int? {
        extraInfo?.meshAddr
    }
}

// MARK: - Location Extra Info

struct LocationExtraInfo: Codable, Equatable {
    let bleMesh: LocationBleMeshInfo?
    let meshAddr: Int?
    let groupElementIds: [String: Int]?
}

// MARK: - BLE Mesh Info

struct LocationBleMeshInfo: Codable, Equatable {
    let uuid: String?
    let networkKeys: [String]?
    let appKeys: [String]?
}

// MARK: - API Response Parsing

extension Location {
    /// Parse locations from API response Data
    static func parseFromAPIResponse(_ data: Data) -> [Location]? {
        let decoder = JSONDecoder()

        // Try to decode as array of locations
        if let locations = try? decoder.decode([Location].self, from: data) {
            return locations
        }

        // Try to decode as a single location wrapped in response
        if let response = try? decoder.decode(LocationListResponse.self, from: data) {
            return response.data
        }

        // Try to decode from dictionary response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return json.compactMap { Location.fromDictionary($0) }
        }

        return nil
    }

    /// Create Location from dictionary
    static func fromDictionary(_ dict: [String: Any]) -> Location? {
        guard let uuid = dict["uuid"] as? String,
              let label = dict["label"] as? String else {
            return nil
        }

        var extraInfo: LocationExtraInfo?
        if let extraDict = dict["extraInfo"] as? [String: Any] {
            var bleMesh: LocationBleMeshInfo?
            if let meshDict = extraDict["bleMesh"] as? [String: Any] {
                bleMesh = LocationBleMeshInfo(
                    uuid: meshDict["uuid"] as? String,
                    networkKeys: meshDict["networkKeys"] as? [String],
                    appKeys: meshDict["appKeys"] as? [String]
                )
            }
            extraInfo = LocationExtraInfo(
                bleMesh: bleMesh,
                meshAddr: extraDict["meshAddr"] as? Int,
                groupElementIds: extraDict["groupElementIds"] as? [String: Int]
            )
        }

        return Location(
            uuid: uuid,
            label: label,
            desc: dict["desc"] as? String,
            userId: dict["userId"] as? String,
            extraInfo: extraInfo,
            createdAt: dict["createdAt"] as? String,
            updatedAt: dict["updatedAt"] as? String
        )
    }
}

// MARK: - Response Wrapper

private struct LocationListResponse: Codable {
    let data: [Location]?
}
