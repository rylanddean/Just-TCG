# BUG-21 — Deck Generator Always Times Out

**Status:** todo  
**Area:** M24 — Deck Generator

## Description

`DeckGeneratorEngine` calls `session.respond(to:)` which blocks until the full response is returned. A 60-card deck list with strategy explanation is a large generation that consistently hits the `LanguageModelSession` default timeout. Users see the spinner for 20–30 seconds before the request fails with a timeout error. No streaming is used, so there is no incremental feedback while the model is working.

## Steps to Reproduce

1. Open the Deck Generator tab (requires iOS 26 + Apple Intelligence)
2. Enter any deck building prompt, e.g. "Build me a competitive Charizard ex deck"
3. Tap Send
4. Wait — the request times out before a response appears

## Observed Behaviour

- Spinner runs for ~20–30 seconds
- Request fails with a timeout or model error
- No incremental output is shown while generation is in progress

## Desired Behaviour

- Generation uses `streamResponse(to:)` so partial output appears progressively in the chat bubble as the model generates it
- The user sees text flowing in immediately (strategy explanation first, then the deck list)
- If the model still takes too long, a manual cancel button is accessible during generation

## Acceptance Criteria

### Streaming
- [ ] `DeckGeneratorEngine.generate(prompt:)` is refactored to use `session.streamResponse(to:)` and yield token-by-token or chunk-by-chunk updates
- [ ] The engine exposes an `AsyncStream<String>` (or `AsyncThrowingStream`) that the view model subscribes to
- [ ] The chat bubble in `DeckGeneratorView` updates in real time as chunks arrive, not only when generation completes

### Cancel
- [ ] A "Stop" button is visible in the input bar whenever generation is in progress
- [ ] Tapping Stop cancels the active streaming task via cooperative cancellation (`Task.cancel()`)
- [ ] The partial response already shown remains visible after cancellation; a "(generation stopped)" indicator is appended

### Error Handling
- [ ] If the stream throws (timeout, model error), the error message is shown inline in the chat bubble rather than as a system alert
- [ ] A "Retry" button appears below the error message that re-sends the last prompt

### Generation Options
- [ ] `LanguageModelSession.respond` / `streamResponse` is called with a `GenerationOptions` that caps `maximumResponseTokens` to a reasonable limit (e.g. 1024) to prevent unbounded generation

## Technical Notes

**Files to change:**
- `JustTCG/Domain/Entities/DeckGeneratorEngine.swift` — replace `session.respond(to:)` with `session.streamResponse(to:)`, return `AsyncThrowingStream<String, Error>`
- `JustTCG/Features/DeckGenerator/DeckGeneratorView.swift` — subscribe to stream, update in-progress chat bubble text
- `JustTCG/Features/DeckGenerator/DeckGeneratorViewModel.swift` — hold the active streaming `Task`, expose `isGenerating` and `cancel()` 

**Stream pattern (FoundationModels iOS 26):**
```swift
func generate(prompt: String) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                let options = GenerationOptions(maximumResponseTokens: 1024)
                for try await partial in session.streamResponse(to: prompt, options: options) {
                    continuation.yield(partial)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
```

`DeckListExtractor.extract(from:)` should be called on the **final** accumulated string once the stream finishes, not on each partial chunk.
