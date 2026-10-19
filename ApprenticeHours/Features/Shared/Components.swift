import SwiftUI

/// Keeps a column of content readable on a large phone without changing anything smaller.
struct MaxContentWidth: ViewModifier {
    var width: CGFloat
    func body(content: Content) -> some View {
        content.frame(maxWidth: width).frame(maxWidth: .infinity)
    }
}

extension View {
    func maxContentWidth(_ width: CGFloat = 640) -> some View { modifier(MaxContentWidth(width: width)) }
}

/// A rounded, grouped-background panel.
struct Panel<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// The headline ring: hours of the required total, with the figure inside it.
/// This is the screen an apprentice opens the app to see, so it gets the space.
struct HoursRing: View {
    let logged: Double
    let required: Double
    var size: CGFloat = 168

    private var fraction: Double { required > 0 ? min(logged / required, 1) : 0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.16), lineWidth: 18)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(Formatters.percent(fraction))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("of \(Formatters.hours(required))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Formatters.hours(logged)) of \(Formatters.hours(required)), \(Formatters.percent(fraction))")
    }
}

/// One work process with its bar. Complete ones go green and stop shouting.
struct CategoryBar: View {
    let progress: HoursMath.CategoryProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(progress.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(progress.required > 0
                     ? "\(Formatters.amount(progress.logged)) / \(Formatters.amount(progress.required))"
                     : Formatters.hours(progress.logged))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(progress.isComplete ? Color.green : Color.primary)
            }
            if progress.required > 0 {
                ProgressView(value: progress.fraction)
                    .tint(progress.isComplete ? .green : .accentColor)
                Text(progress.isComplete ? "Requirement met" : "\(Formatters.hours(progress.remaining)) to go")
                    .font(.caption)
                    .foregroundStyle(progress.isComplete ? .green : .secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A labelled figure.
struct StatBlock: View {
    let value: String
    let label: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// One day in the hours list.
struct EntryRow: View {
    let entry: WorkEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text(Formatters.amount(entry.hours))
                    .font(.headline)
                    .monospacedDigit()
                Text("hr").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.categoryName).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: entry.isSigned ? "signature" : "circle.dashed")
                .foregroundStyle(entry.isSigned ? Color.green : Color.secondary)
                .accessibilityLabel(entry.isSigned ? "Signed" : "Not signed")
        }
        .contentShape(Rectangle())
    }

    private var detail: String {
        var parts = [Formatters.weekdayShort.string(from: entry.date)]
        if !entry.jobSite.isEmpty { parts.append(entry.jobSite) }
        if !entry.supervisor.isEmpty { parts.append(entry.supervisor) }
        if !entry.notes.isEmpty { parts.append(entry.notes) }
        return parts.joined(separator: " · ")
    }
}

/// One class in the related instruction list.
struct ClassRow: View {
    let entry: ClassEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text(Formatters.amount(entry.hours)).font(.headline).monospacedDigit()
                Text("hr").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayTopic).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var detail: String {
        var parts = [Formatters.weekdayShort.string(from: entry.date)]
        if !entry.instructor.isEmpty { parts.append(entry.instructor) }
        if !entry.notes.isEmpty { parts.append(entry.notes) }
        return parts.joined(separator: " · ")
    }
}
