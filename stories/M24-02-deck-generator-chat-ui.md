# M24-02 — Deck Generator Chat UI

**Status:** todo  
**Milestone:** M24 — Natural Language Deck Generator  
**Dependencies:** M24-01

## User Story

As a player, I want to describe the deck I want in plain English and have the app build it for me through a back-and-forth conversation, so I can iterate on the deck without manually searching for cards.

## Acceptance Criteria

### Entry Point
- [ ] A sparkle/wand button (`wand.and.stars`) is added to `DecksView`'s navigation bar (trailing side)
- [ ] Tapping it presents `DeckGeneratorView` as a full-screen cover (`.fullScreenCover`)
- [ ] On pre-iOS 26 or devices without Apple Intelligence, the view still opens and shows the fallback message in the first assistant bubble

### `DeckGeneratorView`
- [ ] New view at `JustTCG/Features/Decks/DeckGeneratorView.swift`
- [ ] Navigation bar titled "Deck Generator" with a "Cancel" button (leading) that dismisses the cover
- [ ] A `ScrollView` with `ScrollViewReader` shows the conversation as message bubbles (same style as `RulesAssistantSheet`)
- [ ] User messages: right-aligned, accent background
- [ ] Assistant messages: left-aligned, secondary background; if the message contains a deck list, it renders a `DeckListPreviewCard` inline beneath the explanation text (see below)
- [ ] Input `HStack` at the bottom: `TextField` ("Describe the deck you want…") + "Send" button disabled during generation
- [ ] A `ProgressView` appears in the conversation while generating
- [ ] Auto-scroll to the latest message on each new message
- [ ] Empty state: prompt text "Describe a deck idea and I'll build it. For example: 'Build me a Charizard ex deck' or 'Something fast with Miraidon ex'."

### `DeckListPreviewCard`
- [ ] New view at `JustTCG/Features/Decks/DeckListPreviewCard.swift`
- [ ] Shows the extracted PTCGL deck list as a scrollable text block styled in monospace caption font inside a rounded card background
- [ ] A prominent "Import Deck" button below the preview triggers deck import (handled in M24-03)
- [ ] The card is only shown when `response.deckList != nil`

### Conversation Flow
- [ ] First message from the user calls `engine.generate(prompt:)`
- [ ] Subsequent messages call `engine.refine(prompt:)` to continue the conversation
- [ ] When the model responds with a follow-up question (`response.isFollowUpQuestion == true`), no import button is shown — just the assistant bubble
- [ ] A "Start over" toolbar button calls `engine.reset()` and clears the local message list

## Technical Notes

**New files:**
- `JustTCG/Features/Decks/DeckGeneratorView.swift`
- `JustTCG/Features/Decks/DeckListPreviewCard.swift`

**Files to change:**
- `JustTCG/Features/Decks/DecksView.swift` — add wand toolbar button + `.fullScreenCover`

**Message model:**
```swift
private struct GeneratorMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    let deckList: String?   // non-nil only for assistant messages that produced a list
    enum Role { case user, assistant }
}
```

**Send action:**
```swift
private func send() {
    let prompt = draft.trimmingCharacters(in: .whitespaces)
    guard !prompt.isEmpty else { return }
    messages.append(GeneratorMessage(role: .user, text: prompt, deckList: nil))
    draft = ""
    isGenerating = true

    Task {
        do {
            let response = messages.count == 1
                ? try await engine.generate(prompt: prompt)
                : try await engine.refine(prompt: prompt)
            messages.append(GeneratorMessage(
                role: .assistant,
                text: response.message,
                deckList: response.deckList
            ))
        } catch {
            messages.append(GeneratorMessage(role: .assistant, text: "Something went wrong. Please try again.", deckList: nil))
        }
        isGenerating = false
    }
}
```
