# M23-03 — Rules Assistant UI

**Status:** done  
**Milestone:** M23 — Rules Assistant  
**Dependencies:** M23-02

## User Story

As a player, I want to tap a help button anywhere in the app to open a rules chat sheet where I can type a question and get an instant answer grounded in the official Pokémon TCG rulebook.

## Acceptance Criteria

### Entry Point
- [x] A `?` toolbar button is added to `HomeView`'s navigation bar (trailing side, alongside the existing gear icon)
- [x] Tapping it presents `RulesAssistantSheet` as a `.sheet`
- [x] On iOS 15 devices (or devices without Apple Intelligence), the button is still visible but tapping it shows the fallback message inside the sheet

### `RulesAssistantSheet`
- [x] A new view at `JustTCG/Features/Rules/RulesAssistantSheet.swift`
- [x] The sheet has a navigation bar titled "Rules Assistant" with a "Done" button to dismiss
- [x] A `ScrollView` shows the conversation as message bubbles:
  - User messages: right-aligned, filled accent-colour background, white text
  - Assistant messages: left-aligned, secondary background fill, primary text
- [x] The scroll view auto-scrolls to the bottom when a new message arrives
- [x] Below the message list, a `HStack` contains a `TextField` ("Ask a rules question…") and a "Send" button
  - The "Send" button is disabled while a response is being generated
  - The text field is disabled during generation
- [x] A `ProgressView` (inline, small) appears inside the conversation while the model is generating
- [x] A "Clear conversation" button in the toolbar calls `engine.reset()` and empties the local message list
- [x] Empty state (no messages yet): a centred prompt reading "Ask anything about Pokémon TCG rules — setup, attacking, special conditions, prizes, and more."

### Availability Handling
- [x] On iOS 26+ devices with Apple Intelligence: fully functional chat
- [x] On iOS 26+ devices without Apple Intelligence enabled: display fallback message in the first assistant bubble
- [x] On iOS < 26: the engine fallback message is shown; no crash

## Technical Notes

**New files:**
- `JustTCG/Features/Rules/RulesAssistantSheet.swift`

**Files to change:**
- `JustTCG/Features/Home/HomeView.swift` — add `?` toolbar button + sheet presentation

**Message model (local to the view file):**
```swift
private struct RulesMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    enum Role { case user, assistant }
}
```

**Send action:**
```swift
private func send() {
    let q = draft.trimmingCharacters(in: .whitespaces)
    guard !q.isEmpty else { return }
    messages.append(RulesMessage(role: .user, text: q))
    draft = ""
    isGenerating = true

    Task {
        do {
            let answer: String
            if #available(iOS 26, *) {
                answer = try await engine.ask(q)
            } else {
                answer = await fallbackEngine.ask(q)
            }
            messages.append(RulesMessage(role: .assistant, text: answer))
        } catch {
            messages.append(RulesMessage(role: .assistant, text: "Something went wrong. Please try again."))
        }
        isGenerating = false
    }
}
```

**Auto-scroll to bottom:**
```swift
.onChange(of: messages.count) {
    withAnimation {
        scrollProxy.scrollTo(messages.last?.id, anchor: .bottom)
    }
}
```
