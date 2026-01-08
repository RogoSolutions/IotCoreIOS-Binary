//
//  Group.swift
//  IoTCoreSample
//
//  Group (Room) model for user groups from API
//

import Foundation

// MARK: - Group Model

struct DeviceGroup: Identifiable, Codable, Equatable {
    let uuid: String
    let label: String
    let desc: String?
    let userId: String?
    let locationId: String?
    let type: Int?
    let elementId: Int?
    let extraInfo: GroupExtraInfo?
    let createdAt: String?
    let updatedAt: String?

    var id: String { uuid }

    // MARK: - Display Helpers

    var displayName: String {
        label.isEmpty ? "Unnamed Group" : label
    }

    var description: String {
        desc ?? ""
    }

    /// Group element ID used for device sync (groupElementId parameter)
    var groupElementId: Int? {
        elementId
    }

    /// Check if this is a room type group (type == 0)
    var isRoom: Bool {
        type == 0
    }
}

// MARK: - Group Extra Info

struct GroupExtraInfo: Codable, Equatable {
    let elementId: Int?
}

// MARK: - API Response Parsing

extension DeviceGroup {
    /// Parse groups from API response Data
    static func parseFromAPIResponse(_ data: Data) -> [DeviceGroup]? {
        let decoder = JSONDecoder()

        // Try to decode as array of groups
        if let groups = try? decoder.decode([DeviceGroup].self, from: data) {
            return groups
        }

        // Try to decode from dictionary response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return json.compactMap { DeviceGroup.fromDictionary($0) }
        }

        return nil
    }

    /// Create Group from dictionary
    static func fromDictionary(_ dict: [String: Any]) -> DeviceGroup? {
        guard let uuid = dict["uuid"] as? String,
              let label = dict["label"] as? String else {
            return nil
        }

        var extraInfo: GroupExtraInfo?
        if let extraDict = dict["extraInfo"] as? [String: Any] {
            extraInfo = GroupExtraInfo(
                elementId: extraDict["elementId"] as? Int
            )
        }

        return DeviceGroup(
            uuid: uuid,
            label: label,
            desc: dict["desc"] as? String,
            userId: dict["userId"] as? String,
            locationId: dict["locationId"] as? String,
            type: dict["type"] as? Int,
            elementId: dict["elementId"] as? Int,
            extraInfo: extraInfo,
            createdAt: dict["createdAt"] as? String,
            updatedAt: dict["updatedAt"] as? String
        )
    }
}
