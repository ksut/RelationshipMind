import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            PeopleListView()
                .tabItem {
                    Label("People", systemImage: "person.2.fill")
                }
                .tag(1)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Person.self, Touchpoint.self, Fact.self, PersonRelationship.self], inMemory: true)
}
