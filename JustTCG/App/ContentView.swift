import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var nav = AppNavigationState()
    @State private var isSeeded = false

    var body: some View {
        ZStack {
            if isSeeded {
                mainTabView
                    .transition(.opacity)
            } else {
                LaunchLoadingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.5), value: isSeeded)
        .task {
            await BundledCardSeeder.seedIfNeeded(context: context)
            isSeeded = true
        }
    }

    private var mainTabView: some View {
        TabView(selection: $nav.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            DecksView()
                .tabItem { Label("Decks", systemImage: "rectangle.stack") }
                .tag(1)
            CardsView()
                .tabItem { Label("Cards", systemImage: "square.grid.2x2") }
                .tag(2)
            CompetitionView()
                .tabItem { Label("Competition", systemImage: "person.2.fill") }
                .tag(3)
            AnalyticsView()
                .tabItem { Label("Prep", systemImage: "chart.bar") }
                .tag(4)
        }
        .environment(nav)
    }
}
