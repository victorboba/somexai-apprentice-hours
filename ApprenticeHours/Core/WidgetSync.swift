import Foundation
import WidgetKit

enum WidgetSync {
    /// Recomputes the widget summary and reloads timelines.
    static func update(program: Program?, categories: [WorkCategory], entries: [WorkEntry], classes: [ClassEntry]) {
        var snapshot = WidgetSnapshot()
        if let program {
            let period = HoursMath.period(containing: .now, period: program.period)
            let totals = HoursMath.totals(in: period, entries: entries, classes: classes)
            snapshot.totalOJT = HoursMath.totalOJT(entries, program: program)
            snapshot.requiredOJT = program.requiredOJT
            snapshot.periodHours = totals.ojt
            snapshot.periodLabel = program.period == .annual
                ? String(Calendar.current.component(.year, from: period.start))
                : Formatters.monthYear.string(from: period.start)
            snapshot.unsignedHours = HoursMath.total(HoursMath.unsigned(entries))
            snapshot.weakestCategory = HoursMath.behind(HoursMath.progress(categories, entries: entries)).first?.name
        }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
