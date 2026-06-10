import SwiftUI

struct HomeView: View {
    @State private var showSettings = false
    @State private var showProfile = false
    @State private var showRulesAssistant = false
    @AppStorage(DevicePerformance.liteModeDefaultsKey) private var liteMode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    StreakWidget()
                    ActivityHeatmapWidget()
                    if !liteMode {
                        FeaturedDeckWidget()
                    }
                    MatchLogWidget()
                }
                .padding(.vertical)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showRulesAssistant = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showRulesAssistant) {
                RulesAssistantSheet()
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}
