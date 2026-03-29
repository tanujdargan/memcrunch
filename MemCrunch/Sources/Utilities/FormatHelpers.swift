import Foundation

enum FormatHelpers {
    static func formatSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    static func formatNumber(_ n: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    static func formatDuration(_ ms: UInt64) -> String {
        if ms < 1000 {
            return "\(ms)ms"
        } else if ms < 60_000 {
            return String(format: "%.1fs", Double(ms) / 1000.0)
        } else {
            let mins = ms / 60_000
            let secs = (ms % 60_000) / 1000
            return "\(mins)m \(secs)s"
        }
    }

    static func formatPercentage(_ value: UInt64, of total: UInt64) -> String {
        guard total > 0 else { return "0%" }
        return String(format: "%.1f%%", Double(value) / Double(total) * 100.0)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

import SwiftUI
