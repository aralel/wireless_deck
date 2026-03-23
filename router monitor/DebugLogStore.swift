//
//  DebugLogStore.swift
//  router monitor
//
//  Created by Codex on 22.03.2026.
//

import Combine
import Foundation
import OSLog

enum AppRuntimeDiagnostics {
    nonisolated static var sandboxContainerID: String? {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"]
    }

    nonisolated static var isSandboxed: Bool {
        sandboxContainerID != nil
    }

    nonisolated static func logLaunchDetails() {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "<unknown>"
        let executablePath = Bundle.main.executableURL?.path ?? "<unknown>"
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let operatingSystem = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        AppLog.info(
            "app",
            "Launch diagnostics bundleID=\(bundleIdentifier) pid=\(ProcessInfo.processInfo.processIdentifier) sandboxed=\(isSandboxed) sandboxContainerID=\(sandboxContainerID ?? "<none>") executable=\(executablePath) os=\(operatingSystem)"
        )
    }
}

enum DebugLogLevel: String, CaseIterable, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"

    nonisolated var osLogType: OSLogType {
        switch self {
        case .debug:
            return .debug
        case .info:
            return .info
        case .warning:
            return .default
        case .error:
            return .error
        }
    }
}

struct DebugLogEntry: Identifiable, Equatable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: DebugLogLevel
    let category: String
    let message: String

    nonisolated var formattedLine: String {
        let timestampString = ISO8601DateFormatter.string(
            from: timestamp,
            timeZone: .current,
            formatOptions: [.withInternetDateTime, .withFractionalSeconds]
        )

        return "[\(timestampString)] [\(level.rawValue)] [\(category)] \(message)"
    }
}

final class DebugLogStore: ObservableObject {
    static let shared = DebugLogStore()

    @Published private(set) var entries: [DebugLogEntry] = []

    private let maxEntries = 600

    private init() {}

    @MainActor
    func append(_ entry: DebugLogEntry) {
        entries.append(entry)

        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    @MainActor
    func clear() {
        entries.removeAll()
    }

    @MainActor
    var combinedText: String {
        entries.map(\.formattedLine).joined(separator: "\n")
    }
}

enum AppLog {
    nonisolated private static let subsystem = Bundle.main.bundleIdentifier ?? "com.aralel.router-monitor"

    nonisolated static func debug(_ category: String, _ message: @autoclosure () -> String) {
        emit(.debug, category: category, message: message())
    }

    nonisolated static func info(_ category: String, _ message: @autoclosure () -> String) {
        emit(.info, category: category, message: message())
    }

    nonisolated static func warning(_ category: String, _ message: @autoclosure () -> String) {
        emit(.warning, category: category, message: message())
    }

    nonisolated static func error(_ category: String, _ message: @autoclosure () -> String) {
        emit(.error, category: category, message: message())
    }

    nonisolated private static func emit(_ level: DebugLogLevel, category: String, message: String) {
        let logger = Logger(subsystem: subsystem, category: category)
        let entry = DebugLogEntry(timestamp: .now, level: level, category: category, message: message)

        logger.log(level: level.osLogType, "\(message, privacy: .public)")
        print(entry.formattedLine)

        Task { @MainActor in
            DebugLogStore.shared.append(entry)
        }
    }
}
