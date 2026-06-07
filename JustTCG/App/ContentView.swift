import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DecksView()
                .tabItem {
                    Label("Decks", systemImage: "rectangle.stack")
                }
            CardsView()
                .tabItem {
                    Label("Cards", systemImage: "square.grid.2x2")
                }
            TournamentsView()
                .tabItem {
                    Label("Tournaments", systemImage: "trophy")
                }
            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar")
                }
        }
    }
}
