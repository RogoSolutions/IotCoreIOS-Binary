//
//  ViewExtensions.swift
//  IoTCoreSample
//
//  Common SwiftUI View extensions
//

import SwiftUI

extension View {
    /// Adds a placeholder view that appears when the condition is met
    ///
    /// Useful for showing placeholder text in TextFields
    ///
    /// Example:
    /// ```swift
    /// TextField("", text: $email)
    ///     .placeholder(when: email.isEmpty) {
    ///         Text("Enter email address")
    ///             .foregroundColor(.gray)
    ///     }
    /// ```
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
