import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())
        let refresh = Calendar.current.date(byAdding: .hour, value: 2, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct ApprenticeHoursWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.requiredOJT > 0 ? "On the job" : "Apprentice Hours")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(Formatters.percent(snapshot.fraction))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("complete").font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(value: snapshot.fraction).tint(.accentColor)
            Text("\(Formatters.hours(snapshot.totalOJT)) of \(Formatters.hours(snapshot.requiredOJT))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if family != .systemSmall {
                Divider()
                Label("\(Formatters.hours(snapshot.periodHours)) in \(snapshot.periodLabel)", systemImage: "calendar")
                    .font(.footnote)
                    .lineLimit(1)
                if snapshot.unsignedHours > 0 {
                    Label("\(Formatters.hours(snapshot.unsignedHours)) unsigned", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else if let weakest = snapshot.weakestCategory {
                    Label("Short on \(weakest)", systemImage: "arrow.down.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ApprenticeHoursWidget: Widget {
    let kind = "ApprenticeHoursWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            ApprenticeHoursWidgetView(entry: entry)
        }
        .configurationDisplayName(AppConfig.appName)
        .description("How far through your hours you are, and what is still unsigned.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ApprenticeHoursWidgetBundle: WidgetBundle {
    var body: some Widget {
        ApprenticeHoursWidget()
    }
}
