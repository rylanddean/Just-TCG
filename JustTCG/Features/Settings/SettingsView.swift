import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("streak_daily_goal") private var dailyGoal: Int = 1
    @AppStorage("deckRowCoverCardCount") private var coverCardCount: Int = 2

    @Query(sort: \Deck.createdAt) private var decks: [Deck]
    @Environment(\.modelContext) private var context

    @State private var showExportError = false
    @State private var exportError = ""

    @State private var showImportPicker = false
    @State private var pendingPayload: BackupPayload? = nil
    @State private var showImportConfirm = false
    @State private var isImporting = false
    @State private var importResult: BackupImportResult? = nil
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importError = ""
    @State private var showUnsupportedBackup = false

    var body: some View {
        NavigationStack {
            Form {
                streakSection
                decksSection
                dataSection
                #if DEBUG
                developerSection
                #endif
            }
            .overlay {
                if isImporting {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Settings")
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Export Failed", isPresented: $showExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError)
            }
            .alert("Import Backup", isPresented: $showImportConfirm) {
                Button("Import") {
                    if let payload = pendingPayload { runImport(payload: payload) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let payload = pendingPayload {
                    let deckCount = payload.decks.count
                    let matchCount = payload.decks.reduce(0) { $0 + $1.matches.count }
                    Text("Import \(deckCount) deck\(deckCount == 1 ? "" : "s") and \(matchCount) match\(matchCount == 1 ? "" : "es")? Decks already on this device will be skipped.")
                }
            }
            .alert("Import Complete", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                if let result = importResult {
                    let skipped = result.decksSkipped > 0
                        ? " \(result.decksSkipped) deck\(result.decksSkipped == 1 ? "" : "s") already existed and were skipped."
                        : ""
                    Text("\(result.decksImported) deck\(result.decksImported == 1 ? "" : "s") and \(result.matchesImported) match\(result.matchesImported == 1 ? "" : "es") imported.\(skipped)")
                }
            }
            .alert("Import Failed", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError)
            }
            .alert("Unsupported Backup", isPresented: $showUnsupportedBackup) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This backup was created with a newer version of JustTCG.")
            }
        }
    }

    // MARK: - Streak

    private var streakSection: some View {
        Section("Streak") {
            Stepper("Goal: \(dailyGoal) game\(dailyGoal == 1 ? "" : "s") / day", value: $dailyGoal, in: 1...10)
        }
    }

    // MARK: - Decks

    private var decksSection: some View {
        Section {
            Picker("Preview cards", selection: $coverCardCount) {
                Text("1").tag(1)
                Text("2").tag(2)
                Text("3").tag(3)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Decks")
        } footer: {
            Text("Number of card images shown on each deck in the decks list.")
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("Data") {
            exportLink
            Button {
                showImportPicker = true
            } label: {
                Label("Import Backup", systemImage: "square.and.arrow.down")
            }
            .disabled(isImporting)
        }
    }

    private var exportLink: some View {
        Group {
            if let backup = makeBackup() {
                ShareLink(item: backup, preview: SharePreview("JustTCG Backup")) {
                    Label("Export Backup", systemImage: "square.and.arrow.up")
                }
            } else {
                Button {
                    exportError = "Could not encode backup data."
                    showExportError = true
                } label: {
                    Label("Export Backup", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private func makeBackup() -> ShareableBackup? {
        guard let data = try? BackupSerializer.encode(decks: decks, streakDailyGoal: dailyGoal) else { return nil }
        return ShareableBackup(data: data, filename: BackupSerializer.fileName())
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try readBackupFile(at: url)
                let payload = try BackupSerializer.decode(from: data)
                guard payload.version <= 1 else {
                    showUnsupportedBackup = true
                    return
                }
                pendingPayload = payload
                showImportConfirm = true
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        }
    }

    private func readBackupFile(at url: URL) throws -> Data {
        guard url.startAccessingSecurityScopedResource() else {
            throw BackupError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try Data(contentsOf: url)
    }

    private func runImport(payload: BackupPayload) {
        isImporting = true
        Task {
            let result = BackupImporter().importPayload(payload, into: context)
            await MainActor.run {
                importResult = result
                showImportSuccess = true
                isImporting = false
            }
        }
    }

    // MARK: - Developer

    #if DEBUG
    private var developerSection: some View {
        Section("Developer") {
            CardCacheDebugRow()
            GameLogsDebugRow()
        }
    }
    #endif
}

// MARK: - Game Logs Debug Row

#if DEBUG
private struct GameLogsDebugRow: View {
    @Environment(\.modelContext) private var context

    @State private var gameCount: Int = 0
    @State private var showConfirm = false

    var body: some View {
        LabeledContent("Live game logs", value: "\(gameCount)")

        Button("Clear game logs", role: .destructive) {
            showConfirm = true
        }
        .confirmationDialog(
            "Delete all \(gameCount) live game log\(gameCount == 1 ? "" : "s")?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) { clearLogs() }
        } message: {
            Text("GameTurn records will also be deleted. Linked match results are kept.")
        }
        .onAppear { refreshCount() }
    }

    private func refreshCount() {
        gameCount = (try? context.fetchCount(FetchDescriptor<LiveGame>())) ?? 0
    }

    private func clearLogs() {
        try? context.delete(model: LiveGame.self)
        try? context.delete(model: GameTurn.self)
        try? context.save()
        refreshCount()
    }
}
#endif

// MARK: - Card Cache Debug Row

#if DEBUG
private struct CardCacheDebugRow: View {
    @Environment(\.modelContext) private var context

    @State private var cardCount: Int = 0
    @State private var lastRefreshed: Date? = nil
    @State private var isSyncing = false
    @State private var statusMessage: String? = nil

    var body: some View {
        Group {
            LabeledContent("Cached cards", value: "\(cardCount)")
            LabeledContent("Last refreshed") {
                Text(lastRefreshed.map { $0.formatted(.relative(presentation: .named)) } ?? "Never")
                    .foregroundStyle(.secondary)
            }

            Button("Force network sync") {
                Task { await forceSync() }
            }
            .disabled(isSyncing)

            Button("Clear card cache", role: .destructive) {
                clearCache()
            }
            .disabled(isSyncing)

            if isSyncing {
                HStack {
                    ProgressView()
                    Text("Syncing…")
                        .foregroundStyle(.secondary)
                }
            }

            if let msg = statusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { refreshStats() }
    }

    private func refreshStats() {
        let descriptor = FetchDescriptor<CachedCard>()
        cardCount = (try? context.fetchCount(descriptor)) ?? 0
        lastRefreshed = UserDefaults.standard.object(forKey: CardRepository.lastRefreshKey) as? Date
    }

    private func forceSync() async {
        isSyncing = true
        statusMessage = nil
        do {
            let repo = CardRepository(modelContext: context)
            try await repo.refreshIfStale(force: true)
            refreshStats()
            statusMessage = "Sync complete."
        } catch {
            statusMessage = "Sync failed: \(error.localizedDescription)"
        }
        isSyncing = false
    }

    private func clearCache() {
        try? context.delete(model: CachedCard.self)
        try? context.save()
        UserDefaults.standard.removeObject(forKey: CardRepository.lastRefreshKey)
        UserDefaults.standard.removeObject(forKey: BundledCardSeeder.seededKey)
        refreshStats()
        statusMessage = "Cache cleared. Re-launch to reseed from bundle."
    }
}
#endif
