//
//  DebugLogView.swift
//  IoTCoreSample
//
//  Debug Log Viewer - Shows SDK debug logs
//

import SwiftUI
import Combine

struct DebugLogView: View {
    @StateObject private var viewModel = DebugLogViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Filter Bar
            filterBar

            // Log Content
            logContentView
        }
        .navigationTitle("Debug Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    viewModel.copyLogs()
                } label: {
                    Image(systemName: "doc.on.doc")
                }

                Button {
                    viewModel.clearLogs()
                } label: {
                    Image(systemName: "trash")
                }
                .foregroundColor(.red)
            }
        }
        .onAppear {
            viewModel.startCapturing()
        }
        .onDisappear {
            viewModel.stopCapturing()
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 8) {
            // Log Level Filter
            Picker("Level", selection: $viewModel.selectedLevel) {
                Text("All").tag(DebugLogLevel.all)
                Text("Info").tag(DebugLogLevel.info)
                Text("Warning").tag(DebugLogLevel.warning)
                Text("Error").tag(DebugLogLevel.error)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)

            // Log Stats
            HStack {
                Text("\(viewModel.filteredLogs.count) logs")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.isCapturing {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Live")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Log Content

    private var logContentView: some View {
        Group {
            if viewModel.filteredLogs.isEmpty {
                emptyStateView
            } else {
                logListView
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Logs")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Debug logs will appear here when SDK operations are performed.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var logListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.filteredLogs) { log in
                        LogEntryRow(log: log)
                            .id(log.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: viewModel.filteredLogs.count) { _ in
                if viewModel.autoScroll, let lastLog = viewModel.filteredLogs.last {
                    withAnimation {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let log: DebugLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                // Level Indicator
                Circle()
                    .fill(log.level.color)
                    .frame(width: 8, height: 8)

                // Timestamp
                Text(log.formattedTimestamp)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)

                // Tag
                if let tag = log.tag {
                    Text("[\(tag)]")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.blue)
                }
            }

            // Message
            Text(log.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(log.level.textColor)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(log.level.backgroundColor)
        .cornerRadius(4)
    }
}

// MARK: - Log Entry Model

struct DebugLogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let level: DebugLogLevel
    let message: String
    let tag: String?

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Log Level

enum DebugLogLevel: String, CaseIterable {
    case all
    case info
    case warning
    case error

    var color: Color {
        switch self {
        case .all: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    var textColor: Color {
        switch self {
        case .all, .info: return .primary
        case .warning: return .orange
        case .error: return .red
        }
    }

    var backgroundColor: Color {
        switch self {
        case .all, .info: return Color(.systemBackground)
        case .warning: return Color.orange.opacity(0.1)
        case .error: return Color.red.opacity(0.1)
        }
    }
}

// MARK: - ViewModel

@MainActor
class DebugLogViewModel: ObservableObject {
    @Published var logs: [DebugLogEntry] = []
    @Published var selectedLevel: DebugLogLevel = .all
    @Published var searchText: String = ""
    @Published var isCapturing: Bool = false
    @Published var autoScroll: Bool = true

    private var captureTask: Task<Void, Never>?

    var filteredLogs: [DebugLogEntry] {
        logs.filter { log in
            // Level filter
            let levelMatch = selectedLevel == .all || log.level == selectedLevel

            // Search filter
            let searchMatch = searchText.isEmpty ||
                log.message.localizedCaseInsensitiveContains(searchText) ||
                (log.tag?.localizedCaseInsensitiveContains(searchText) ?? false)

            return levelMatch && searchMatch
        }
    }

    func startCapturing() {
        isCapturing = true

        // Add some sample logs for demonstration
        // In a real implementation, this would hook into the SDK's logging system
        addSampleLogs()
    }

    func stopCapturing() {
        isCapturing = false
        captureTask?.cancel()
    }

    func clearLogs() {
        logs.removeAll()
    }

    func copyLogs() {
        let logText = filteredLogs.map { log in
            let tag = log.tag.map { "[\($0)] " } ?? ""
            return "[\(log.formattedTimestamp)] [\(log.level.rawValue.uppercased())] \(tag)\(log.message)"
        }.joined(separator: "\n")

        UIPasteboard.general.string = logText
    }

    private func addSampleLogs() {
        // Add some demonstration logs
        // In production, these would come from the actual SDK logging system
        let sampleLogs: [(DebugLogLevel, String, String?)] = [
            (.info, "SDK initialized successfully", "SDK"),
            (.info, "Configuration loaded from UserDefaults", "Config"),
            (.info, "Environment: Staging", "Config"),
            (.warning, "Network connectivity check pending", "Network"),
            (.info, "BLE Central Manager initialized", "BLE"),
            (.info, "Ready to scan for devices", "BLE"),
        ]

        for (level, message, tag) in sampleLogs {
            logs.append(DebugLogEntry(
                timestamp: Date(),
                level: level,
                message: message,
                tag: tag
            ))
        }
    }

    func addLog(level: DebugLogLevel, message: String, tag: String? = nil) {
        let entry = DebugLogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            tag: tag
        )
        logs.append(entry)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        DebugLogView()
    }
}
