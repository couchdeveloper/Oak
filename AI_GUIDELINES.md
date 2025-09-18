# AI Guidelines for This Repository

## Purpose
- Provide clear, tool‑agnostic rules for AI assistants.
- Keep guidance concise and actionable. Detailed context lives in `.github/copilot-instructions.md`.

## Core Principles
- Follow Oak’s FSM architecture: pure `update`; side effects in `Effect`.
- Do not migrate XCTest to Swift Testing unless explicitly requested.
- Prefer Swift + Swift Concurrency and explicit isolation; be flexible if the codebase indicates otherwise.
- Keep user‑facing `Output` separate from `Effect` semantics.

## FSM Rules
- `update` functions are pure: no I/O, no sleeping, no global mutations, avoid capturing mutable external state.
- Effects
  - Action events are processed synchronously in the computation cycle.
  - When state becomes terminal: deliver output (if any), execute any final effect for cleanup, stop further event processing; proxy finishes immediately.
- Use enums for State; implement and respect `isTerminal` explicitly.
- Prefer synchronous actions for performance; use operations for real async work.

## Concurrency
- Respect actor isolation; values crossing isolation must be `Sendable`.
- Avoid introducing global state, hidden side effects, or unbounded tasks.
- Do not “fix” intentionally thread‑unsafe APIs unless asked.

## Coding Conventions
- Keep files small and focused; mirror `Sources/Oak/{FSM,SwiftUI}/` layout.
- Prefer sum types (enums) for states; structs for data payloads with computed properties.
- Document framework‑internal APIs clearly and mark framework‑only surfaces.
- Maintain minimal, surgical changes; avoid unrelated refactors.

## Testing
- Deterministic tests; no networking, real timers, or clock drift.
- Keep existing XCTest unless explicitly asked to adopt Swift Testing.
- Use provided test utilities in `Tests/OakTests/Utilities`.

## Do / Don’t
- Do add documentation/comments when changing terminal‑state or effect logic.
- Do propose full‑file edits when modifying an existing file (no elisions in patched samples).
- Don’t introduce breaking API changes without a clear "Breaking Changes" note.
- Don’t refactor architecture patterns (e.g., to Combine) unless requested.

## Discovery Hints for AI
- Read `.github/copilot-instructions.md` for detailed framework context and patterns.
- Key files:
  - `Sources/Oak/FSM/Transducer.swift`
  - `Sources/Oak/FSM/Effect.swift`
  - `Sources/Oak/FSM/Proxy.swift`
  - `Sources/Oak/SwiftUI/TransducerView.swift`

## References
- Detailed guidance: `.github/copilot-instructions.md`
