import SwiftUI
import SwiftData
import UIKit

private extension TimeInterval {
    var mmss: String {
        let total = Int(max(0, self))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct LiveGameHUDView: View {
    let game: LiveGame
    let onDismiss: (Bool) -> Void

    @Environment(\.modelContext) private var context
    @State private var vm: LiveGameHUDViewModel?

    var body: some View {
        Group {
            if let vm {
                HUDContent(vm: vm, onDismiss: onDismiss)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            vm?.stopTurnReminderTimer()
        }
        .task {
            if vm == nil {
                vm = LiveGameHUDViewModel(game: game, modelContext: context)
            }
        }
    }
}

// MARK: - HUD Content

private struct HUDContent: View {
    @Bindable var vm: LiveGameHUDViewModel
    let onDismiss: (Bool) -> Void

    @State private var gameOverAlertShown = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                hudDivider
                prizeSection(isPlayer: false)
                hudDivider
                turnBanner
                hudDivider
                prizeSection(isPlayer: true)
                hudDivider
                endTurnButton
            }
            if vm.needsCoinFlip {
                coinFlipOverlay
            }
        }
        .foregroundStyle(.white)
        .sheet(isPresented: $vm.showEndGame) {
            EndGameSheet(vm: vm) { confirmed in
                if confirmed {
                    let match = vm.endGame()
                    vm.showEndGame = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        onDismiss(match != nil)
                    }
                } else {
                    vm.showEndGame = false
                }
            }
        }
        .alert(
            "Reverse Prize?",
            isPresented: Binding<Bool>(
                get: { vm.reverseAlertForPlayer != nil },
                set: { if !$0 { vm.reverseAlertForPlayer = nil } }
            )
        ) {
            Button("Reverse") {
                if let side = vm.reverseAlertForPlayer { vm.reversePrize(byPlayer: side) }
                vm.reverseAlertForPlayer = nil
            }
            Button("Cancel", role: .cancel) { vm.reverseAlertForPlayer = nil }
        } message: {
            Text("Un-take this prize? Use only to fix a mis-tap.")
        }
        .alert("Game Over?", isPresented: $gameOverAlertShown) {
            Button("Log Result") { vm.showEndGame = true }
            Button("Keep Playing", role: .cancel) { }
        } message: {
            Text(vm.game.playerPrizesRemaining == 0
                 ? "You've taken all 6 prizes."
                 : "Your opponent has taken all 6 prizes.")
        }
        .onChange(of: vm.isGameOver) { _, isOver in
            if isOver && !gameOverAlertShown { gameOverAlertShown = true }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            TimelineView(.periodic(from: vm.game.startedAt, by: 1)) { ctx in
                let elapsed = ctx.date.timeIntervalSince(vm.game.startedAt)
                Label(elapsed.mmss, systemImage: "timer")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Button { vm.showEndGame = true } label: {
                Label("End Game", systemImage: "stop.circle.fill")
                    .font(.callout.weight(.medium))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Prize sections

    private func prizeSection(isPlayer: Bool) -> some View {
        let prizes = isPlayer ? vm.game.playerPrizesRemaining : vm.game.opponentPrizesRemaining
        let isActive = isPlayer ? vm.isPlayerTurn : !vm.isPlayerTurn
        let heading = isPlayer ? "You" : "Opponent"
        let subheading: String? = isPlayer ? vm.game.deck?.name : vm.game.opponentArchetype

        return HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(heading)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                if let sub = subheading {
                    Text(sub)
                        .font(.callout)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: 90, alignment: .leading)
            Spacer()
            prizeGrid(prizesRemaining: prizes, isPlayer: isPlayer)
            Text("\(prizes)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .frame(width: 52, alignment: .trailing)
                .foregroundStyle(prizes == 0 ? Color.red : Color.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
        .animation(.easeInOut(duration: 0.3), value: vm.isPlayerTurn)
    }

    private func prizeGrid(prizesRemaining: Int, isPlayer: Bool) -> some View {
        let columns = Array(repeating: GridItem(.fixed(40), spacing: 6), count: 3)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<6, id: \.self) { i in
                let isRemaining = i < prizesRemaining
                Circle()
                    .fill(isRemaining ? Color.white : Color.white.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay {
                        if !isRemaining {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                    }
                    .onTapGesture {
                        guard isRemaining else { return }
                        vm.takePrize(byPlayer: isPlayer)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        guard !isRemaining else { return }
                        vm.reverseAlertForPlayer = isPlayer
                    }
            }
        }
    }

    // MARK: - Turn banner

    private var turnBanner: some View {
        HStack {
            if let turn = vm.activeTurn {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Turn \(turn.turnNumber)")
                        .font(.headline)
                    Text(vm.isPlayerTurn ? "Your Turn" : "Their Turn")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                TimelineView(.periodic(from: turn.startedAt, by: 1)) { ctx in
                    Text(ctx.date.timeIntervalSince(turn.startedAt).mmss)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                }
            } else {
                Text("Waiting to start…")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - End Turn button

    private var endTurnButton: some View {
        Button {
            vm.endTurn()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Text("End Turn")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(vm.needsCoinFlip ? Color.gray.opacity(0.4) : Color.accentColor)
                .foregroundStyle(.white)
        }
        .disabled(vm.needsCoinFlip)
    }

    // MARK: - Coin flip overlay

    private var coinFlipOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Who's Going First?")
                        .font(.title2.weight(.bold))
                    Text("Tap your result from the coin flip.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 12) {
                    Button {
                        vm.confirmGoingFirst(isPlayerFirst: true)
                    } label: {
                        Text("I'm Going First")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button {
                        vm.confirmGoingFirst(isPlayerFirst: false)
                    } label: {
                        Text("They're Going First")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(32)
        }
    }

    // MARK: - Divider

    private var hudDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
    }
}

// MARK: - End Game Sheet

private struct EndGameSheet: View {
    @Bindable var vm: LiveGameHUDViewModel
    let onDone: (Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Result") {
                    resultRow(.win, label: "Win")
                    resultRow(.loss, label: "Loss")
                    resultRow(.tie, label: "Tie")
                }
                Section("Notes") {
                    TextField("Optional notes", text: $vm.endGameNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    let turnNum = vm.activeTurn?.turnNumber ?? 0
                    Label(
                        "Turn \(turnNum) · \(vm.game.playerPrizesRemaining) yours · \(vm.game.opponentPrizesRemaining) theirs",
                        systemImage: "square.grid.2x2"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("End Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone(false) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onDone(true) }
                        .fontWeight(.semibold)
                        .disabled(vm.endGameResult == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func resultRow(_ result: MatchResult, label: String) -> some View {
        Button {
            vm.endGameResult = result
        } label: {
            HStack {
                Text(label).foregroundStyle(.primary)
                Spacer()
                if vm.endGameResult == result {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}
