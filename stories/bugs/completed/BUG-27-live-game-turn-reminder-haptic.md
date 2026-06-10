# BUG-27 — Live Game HUD: Users Forget to End Their Turn

**Status:** done  
**Area:** Live Game HUD

## Description

When tracking a live game, users frequently forget to tap "End Turn" after their turn ends in real life. The idle HUD gives no feedback that a turn is still in progress. Missing "End Turn" taps corrupt the turn-duration data stored per `GameTurn` and throw off total turn counts. A periodic haptic reminder while the current turn exceeds a threshold would prompt the user to act without requiring them to watch the screen.

## Steps to Reproduce

1. Start a live game and begin a turn
2. Play through a real game turn without tapping "End Turn"
3. Check game log — turn duration is inflated or incorrect

## Observed Behaviour

- No feedback after a turn starts if the user stops interacting with the HUD
- Users regularly forget to end their turn, producing artificially long turn durations
- If the phone screen locks, the idle timer is already disabled but there is still no tactile prompt

## Desired Behaviour

After a turn has been active for 30 seconds with no interaction, the device vibrates once as a reminder. The haptic repeats every 30 seconds until the turn ends. Reminders stop immediately when the user taps "End Turn", takes a prize, or dismisses the game.

## Acceptance Criteria

### Periodic reminder
- [ ] A repeating timer is started when a new turn begins (`vm.endTurn()` clears and restarts it)
- [ ] The timer fires every 30 seconds while the game is in a player-turn state (`vm.activeTurn != nil` and the game is not over)
- [ ] Each firing triggers `UINotificationFeedbackGenerator(type: .warning).notificationOccurred()`
- [ ] The timer is invalidated when:
  - `vm.endTurn()` is called
  - `vm.takePrize(byPlayer:)` is called (user is interacting)
  - The game ends (`onDismiss` is fired)
  - `LiveGameHUDView.onDisappear` fires

### No regressions
- [ ] The existing `UIImpactFeedbackGenerator` calls on prize tap and End Turn are unchanged
- [ ] `UIApplication.shared.isIdleTimerDisabled = true` is unchanged
- [ ] The reminder does not fire during the coin-flip overlay (`vm.needsCoinFlip == true`)

## Technical Notes

**Files to change:**
- `JustTCG/Features/LiveGame/LiveGameHUDViewModel.swift` — add `startTurnReminderTimer()` / `stopTurnReminderTimer()` using a `Timer` (or `Task` with `Task.sleep` loop); call on turn start/end
- `JustTCG/Features/LiveGame/LiveGameHUDView.swift` — cancel timer on `onDisappear`; ensure `needsCoinFlip` suppresses it

**Haptic pattern:**
```swift
UINotificationFeedbackGenerator().notificationOccurred(.warning)
```
