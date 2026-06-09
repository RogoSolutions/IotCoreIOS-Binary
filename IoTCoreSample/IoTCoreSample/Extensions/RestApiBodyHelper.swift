//
//  RestApiBodyHelper.swift
//  IoTCoreSample
//
//  Helper to bridge the legacy dictionary-based call sites to the new
//  String-based `body:` parameter of the generic callApi* primitives (T-004).
//
//  The Core SDK now takes a raw `body: String?`; the sample app historically
//  built `[String: Any]` payloads. This helper serialises those dictionaries
//  into a JSON string so existing sample flows keep working.
//

import Foundation

/// Serialise a `[String: Any]` payload into a JSON `String` suitable for the
/// `body:` parameter of `callApiPost/Patch/Update/Delete`.
///
/// Returns `nil` when the dictionary is empty or cannot be serialised, in which
/// case the request is sent without a body.
func jsonBody(_ params: [String: Any]?) -> String? {
    guard let params = params, !params.isEmpty else { return nil }
    guard JSONSerialization.isValidJSONObject(params),
          let data = try? JSONSerialization.data(withJSONObject: params, options: []),
          let string = String(data: data, encoding: .utf8) else {
        return nil
    }
    return string
}
