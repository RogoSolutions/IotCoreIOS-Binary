//
//  CommandParameterFormView.swift
//  IoTCoreSample
//
//  Created on 2025-01-19.
//  Dynamic form view for editing device command parameters
//

import SwiftUI
import UIKit

// MARK: - ParameterType Extensions

extension ParameterType {
    /// Display name for the parameter type
    var displayName: String {
        switch self {
        case .string:
            return "Text"
        case .int:
            return "Integer"
        case .intArray:
            return "Integer Array"
        case .double:
            return "Decimal"
        case .bool:
            return "Boolean"
        case .uint8:
            return "Byte (0-255)"
        case .uint8Array:
            return "Byte Array"
        }
    }

    /// Keyboard type for the parameter input
    var keyboardType: UIKeyboardType {
        switch self {
        case .string:
            return .default
        case .int, .uint8:
            return .numberPad
        case .intArray, .uint8Array:
            return .numbersAndPunctuation
        case .double:
            return .decimalPad
        case .bool:
            return .default // Not used for bool (Toggle)
        }
    }

    /// Format hint for array types
    var formatHint: String? {
        switch self {
        case .intArray:
            return "Format: 1,2,3 or [1,2,3]"
        case .uint8Array:
            return "Format: 0,255,128 (values 0-255)"
        default:
            return nil
        }
    }
}

// MARK: - CommandParameterFormView

/// A dynamic form view that generates input fields based on command parameters
struct CommandParameterFormView: View {
    let command: DeviceCommand
    let deviceId: String
    @Binding var parameterValues: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if command.parameters.isEmpty {
                emptyParametersView
            } else {
                ForEach(command.parameters, id: \.name) { parameter in
                    parameterInputView(for: parameter)
                }
            }
        }
        .onAppear {
            initializeParameterValues()
        }
    }

    // MARK: - Empty Parameters View

    private var emptyParametersView: some View {
        HStack {
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)
            Text("No parameters required")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Parameter Input View

    @ViewBuilder
    private func parameterInputView(for parameter: CommandParameter) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label with required indicator
            HStack(spacing: 4) {
                Text(parameter.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if parameter.isRequired {
                    Text("*")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()

                Text(parameter.type.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }

            // Input field based on type
            switch parameter.type {
            case .bool:
                boolInputView(for: parameter)
            default:
                textInputView(for: parameter)
            }

            // Help text or format hint
            if let helpText = parameter.helpText {
                Text(helpText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if let formatHint = parameter.type.formatHint {
                Text(formatHint)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Text Input View

    private func textInputView(for parameter: CommandParameter) -> some View {
        let binding = Binding<String>(
            get: { parameterValues[parameter.name] ?? "" },
            set: { parameterValues[parameter.name] = $0 }
        )

        return TextField(parameter.placeholder, text: binding)
            .textFieldStyle(.roundedBorder)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .keyboardType(parameter.type.keyboardType)
            .disabled(isDevIdParameterAutoFilled(parameter))
            .opacity(isDevIdParameterAutoFilled(parameter) ? 0.7 : 1.0)
    }

    // MARK: - Bool Input View

    private func boolInputView(for parameter: CommandParameter) -> some View {
        let binding = Binding<Bool>(
            get: {
                let value = parameterValues[parameter.name] ?? parameter.defaultValue
                return value.lowercased() == "true" || value == "1"
            },
            set: { newValue in
                parameterValues[parameter.name] = newValue ? "true" : "false"
            }
        )

        return Toggle(isOn: binding) {
            Text(parameter.placeholder.isEmpty ? (binding.wrappedValue ? "Enabled" : "Disabled") : parameter.placeholder)
                .font(.subheadline)
        }
        .toggleStyle(SwitchToggleStyle(tint: .blue))
        .padding(.vertical, 4)
    }

    // MARK: - Helper Methods

    /// Initialize parameter values with defaults
    private func initializeParameterValues() {
        for parameter in command.parameters {
            // Skip if already has a value
            if parameterValues[parameter.name] != nil && !parameterValues[parameter.name]!.isEmpty {
                continue
            }

            // Auto-fill devId with current device ID
            if parameter.name == "devId" {
                parameterValues[parameter.name] = deviceId
            } else if !parameter.defaultValue.isEmpty {
                parameterValues[parameter.name] = parameter.defaultValue
            }
        }
    }

    /// Check if this is a devId parameter that should be auto-filled and disabled
    private func isDevIdParameterAutoFilled(_ parameter: CommandParameter) -> Bool {
        return parameter.name == "devId" && !deviceId.isEmpty
    }
}

// MARK: - Preview

#Preview("Control Device Command") {
    ScrollView {
        VStack(spacing: 20) {
            CommandParameterFormView(
                command: .controlDevice,
                deviceId: "test-device-uuid-123",
                parameterValues: .constant([:])
            )
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
    }
}

#Preview("Get Device State Command") {
    ScrollView {
        VStack(spacing: 20) {
            CommandParameterFormView(
                command: .getDeviceState,
                deviceId: "test-device-uuid-456",
                parameterValues: .constant([:])
            )
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
    }
}

#Preview("Update Device Software Command") {
    ScrollView {
        VStack(spacing: 20) {
            CommandParameterFormView(
                command: .updateDeviceSoftware,
                deviceId: "test-device-uuid-789",
                parameterValues: .constant([:])
            )
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
    }
}

#Preview("Stop Wile Direct BLE (No Params)") {
    ScrollView {
        VStack(spacing: 20) {
            CommandParameterFormView(
                command: .stopWileDirectBle,
                deviceId: "test-device-uuid",
                parameterValues: .constant([:])
            )
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
    }
}

#Preview("Send Vendor Message Bytes") {
    ScrollView {
        VStack(spacing: 20) {
            CommandParameterFormView(
                command: .sendVendorMsgBytes,
                deviceId: "test-device-uuid",
                parameterValues: .constant([:])
            )
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
    }
}
