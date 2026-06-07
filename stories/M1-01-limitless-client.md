# M1-01 — Limitless TCG Client Foundation

**Status:** todo  
**Milestone:** M1 — Card Browser  
**Dependencies:** M0

## User Story
As a developer, I need a `LimitlessTCGClient` that handles all network communication with Limitless TCG so that card and tournament data can be fetched reliably with proper error handling and retry logic.

## Acceptance Criteria

- [ ] `LimitlessTCGClient` struct lives in `Data/LimitlessTCGClient/`
- [ ] Implements `fetchStandardCards(page: Int) async throws -> [LimitlessCard]`
- [ ] Implements `fetchCard(id: String) async throws -> LimitlessCard`
- [ ] `LimitlessCard` is a plain Swift struct (no SwiftData) with fields: `id`, `name`, `setCode`, `setName`, `number`, `types`, `subtypes`, `hp`, `isStandardLegal`, `imageURL`
- [ ] All requests use `URLSession` with `async/await` — no third-party networking libs
- [ ] Retry logic: up to 3 attempts with exponential backoff (1s, 2s, 4s) on network errors
- [ ] `DecodingError` is caught and re-thrown as a typed `LimitlessClientError.decodingFailed` — never surfaces raw `DecodingError` to callers
- [ ] A `NetworkError.offline` case is returned when the device has no connectivity
- [ ] Unit tests cover: successful decode, decode failure, retry exhaustion

## Technical Notes

- Base URL: `https://limitlesstcg.com`
- The card list endpoint accepts query params for format filtering — pass `format=standard` to filter server-side
- Response shape should be confirmed by inspecting the network tab on limitlesstcg.com/cards before finalising the `Codable` structs
- Keep the client a pure `struct` with no stored state — pass a `URLSession` in the initialiser (default: `.shared`) for testability
