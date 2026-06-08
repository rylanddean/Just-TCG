# M27-02 — Export & Import UI in Settings

**Status:** done  
**Milestone:** M27 — Backlog Export & Import  
**Dependencies:** M27-01

## User Story

As a player, I want to export all my decks and match history to a file so I can back them up or move them to another device, and import a backup file to restore my data.

## Acceptance Criteria

### Settings Section

- [ ] A new "Data" section is added to `SettingsView` between the existing Decks section and the DEBUG section
- [ ] The section contains two rows: **Export Backup** and **Import Backup**

### Export

- [ ] "Export Backup" is a `ShareLink` that:
  - Queries all `Deck` objects via `@Query` in `SettingsView`
  - Reads `streakDailyGoal` from `@AppStorage`
  - Calls `BackupSerializer.encode(decks:streakDailyGoal:)` to produce the JSON `Data`
  - Wraps it in a `ShareableBackup` transferable (see below) so `ShareLink` can present it with the correct filename
  - The share sheet subject line is "JustTCG Backup"
- [ ] If encoding throws, a `.alert` is shown: "Export Failed — [error message]"
- [ ] The export button label: `Label("Export Backup", systemImage: "square.and.arrow.up")`

### `ShareableBackup` Transferable

- [ ] A new `struct ShareableBackup: Transferable` at `JustTCG/Data/Backup/ShareableBackup.swift`
- [ ] Conforms to `Transferable` via a `DataRepresentation` with content type `.json`
- [ ] Exposes `filename: String` (from `BackupSerializer.fileName()`) for use as the share sheet filename:
  ```swift
  struct ShareableBackup: Transferable {
      let data: Data
      let filename: String

      static var transferRepresentation: some TransferRepresentation {
          DataRepresentation(contentType: .json) { $0.data }
              exportingCondition: { _ in true }
      }
  }
  ```
  > Use `FileRepresentation` or `DataRepresentation` — whichever cleanly surfaces the filename in the share sheet. `FileRepresentation` writing to a temp file is preferred since it preserves the filename in AirDrop and Files saves.

### Import

- [ ] "Import Backup" is a `Button` that sets `showImportPicker = true`
- [ ] `.fileImporter(isPresented:, allowedContentTypes: [.json], allowsMultipleSelection: false)` handles the file pick
- [ ] On file selection:
  1. Read `Data` from the selected URL (using security-scoped resource access: `url.startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`)
  2. Call `BackupSerializer.decode(from:)` to validate and parse the payload
  3. If version is unsupported (> 1), show an alert: "Unsupported Backup — This backup was created with a newer version of JustTCG."
  4. Show a confirmation alert summarising what will be imported: "Import [N] deck(s) and [M] match(es)? Decks already on this device will be skipped." with **Import** (default) and **Cancel** buttons
  5. On confirmation, call `BackupImporter().importPayload(_:into:)` on the main thread
  6. Show a success alert: "Import Complete — [N] deck(s) and [M] match(es) imported. [K] deck(s) already existed and were skipped." (omit skipped sentence if K == 0)
- [ ] Import errors (bad JSON, unreadable file) show an alert: "Import Failed — [error message]"
- [ ] The import button label: `Label("Import Backup", systemImage: "square.and.arrow.down")`
- [ ] A `ProgressView` overlay appears on the Form while import is in progress (import is async; button is disabled)

### State & Alerts

- [ ] All alert and sheet state is managed locally in `SettingsView` with `@State` — no new view model needed
- [ ] Alerts use SwiftUI's `.alert(_:isPresented:actions:message:)` modifier

## Technical Notes

**New file:** `JustTCG/Data/Backup/ShareableBackup.swift`

**Files to change:**
- `JustTCG/Features/Settings/SettingsView.swift` — add Data section, export ShareLink, import button + fileImporter

**Query in `SettingsView`:**
```swift
@Query(sort: \Deck.createdAt) private var decks: [Deck]
@Environment(\.modelContext) private var context
@AppStorage("streak_daily_goal") private var dailyGoal: Int = 1
```

**Export ShareLink pattern:**
```swift
private var exportLink: some View {
    Group {
        if let backup = makeBackup() {
            ShareLink(item: backup, preview: SharePreview("JustTCG Backup")) {
                Label("Export Backup", systemImage: "square.and.arrow.up")
            }
        } else {
            Button("Export Backup", systemImage: "square.and.arrow.up") {
                exportError = "Could not encode backup data."
                showExportError = true
            }
        }
    }
}

private func makeBackup() -> ShareableBackup? {
    guard let data = try? BackupSerializer.encode(decks: decks, streakDailyGoal: dailyGoal) else { return nil }
    return ShareableBackup(data: data, filename: BackupSerializer.fileName())
}
```

**Security-scoped file read:**
```swift
func readBackupFile(at url: URL) throws -> Data {
    guard url.startAccessingSecurityScopedResource() else {
        throw BackupError.accessDenied
    }
    defer { url.stopAccessingSecurityScopedResource() }
    return try Data(contentsOf: url)
}
```

**Import async pattern (keeps UI responsive):**
```swift
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
```
