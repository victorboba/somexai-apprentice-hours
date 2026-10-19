import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HoursProgressView()
                .tabItem { Label("Progress", systemImage: "chart.pie.fill") }
            HoursListView()
                .tabItem { Label("Hours", systemImage: "clock.fill") }
            ClassListView()
                .tabItem { Label("Classes", systemImage: "book.fill") }
            ReportView()
                .tabItem { Label("Report", systemImage: "doc.text.fill") }
        }
    }
}
