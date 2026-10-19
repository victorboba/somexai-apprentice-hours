import Foundation

enum CSVExporter {
    static let entryHeader = "date,work_process,hours,job_site,supervisor,signed,signed_by,signed_on,notes"
    static let classHeader = "date,hours,topic,instructor,notes"
    static let summaryHeader = "work_process,hours_logged,hours_required,hours_remaining,percent_complete"

    static func entriesCSV(_ entries: [WorkEntry]) -> String {
        var lines = [entryHeader]
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            let fields = [
                Formatters.isoDay.string(from: entry.date),
                entry.categoryName,
                Formatters.amount(entry.hours),
                entry.jobSite,
                entry.supervisor,
                entry.isSigned ? "yes" : "no",
                entry.signedBy,
                entry.signedAt.map(Formatters.isoDay.string(from:)) ?? "",
                entry.notes.replacingOccurrences(of: "\n", with: " "),
            ]
            lines.append(fields.map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func classesCSV(_ classes: [ClassEntry]) -> String {
        var lines = [classHeader]
        for entry in classes.sorted(by: { $0.date < $1.date }) {
            let fields = [
                Formatters.isoDay.string(from: entry.date),
                Formatters.amount(entry.hours),
                entry.displayTopic,
                entry.instructor,
                entry.notes.replacingOccurrences(of: "\n", with: " "),
            ]
            lines.append(fields.map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func summaryCSV(_ progress: [HoursMath.CategoryProgress]) -> String {
        var lines = [summaryHeader]
        for row in progress {
            let fields = [
                row.name,
                Formatters.amount(row.logged),
                row.required > 0 ? Formatters.amount(row.required) : "",
                row.required > 0 ? Formatters.amount(row.remaining) : "",
                row.required > 0 ? Formatters.percent(row.fraction) : "",
            ]
            lines.append(fields.map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func write(_ text: String, suffix: String) throws -> URL {
        let url = ExportFile.temporaryURL(suffix: suffix, extension: "csv")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func quote(_ field: String) -> String {
        "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// A file URL wrapped so it can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.path }

    static func temporaryURL(suffix: String, extension ext: String) -> URL {
        let stamp = DateFormatter.fileStamp.string(from: .now)
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppConfig.exportFileStem)-\(suffix)-\(stamp)")
            .appendingPathExtension(ext)
    }
}

extension DateFormatter {
    static let fileStamp: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd-HHmm"; return f
    }()
}

extension Formatters {
    static let isoDay: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}
