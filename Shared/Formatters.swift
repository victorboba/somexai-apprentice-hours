import Foundation

enum Formatters {
    static let dateTime: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()
    static let date: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
    /// "Sep 16"
    static let short: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    /// "Wed, Sep 16"
    static let weekdayShort: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f
    }()
    /// "September 2026"
    static let monthYear: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()

    /// "8" / "7.5", trimming trailing zeros.
    static func amount(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        let s = String(format: "%.2f", value)
        return s.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    }

    /// "1,240 hr", which is how a sponsor reads a total.
    static func hours(_ value: Double) -> String {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        n.maximumFractionDigits = value == value.rounded() ? 0 : 2
        return "\(n.string(from: NSNumber(value: value)) ?? amount(value)) hr"
    }

    static func percent(_ fraction: Double) -> String { "\(Int((fraction * 100).rounded()))%" }

    /// "2 yr 4 mo" / "7 mo", the long units the owner asked for.
    static func months(_ months: Int) -> String {
        let years = months / 12, rest = months % 12
        if years == 0 { return "\(rest) mo" }
        return rest == 0 ? "\(years) yr" : "\(years) yr \(rest) mo"
    }
}
