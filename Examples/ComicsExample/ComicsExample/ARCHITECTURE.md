# Oak Feature Architecture — Opinionated, Scalable Pattern (Comics Example)

This document presents a minimal, scalable architecture for Oak-based SwiftUI apps. It emphasizes pure feature logic, explicit side effects, and clear module boundaries. The Comics example illustrates the pattern, but the guidance is generic and applies to any feature.

## Architectural Assumption: A SwiftUI View Is Not (Solely) a View

Oak’s architecture is based on the principle that a SwiftUI `View` is not just a UI renderer. In Oak, views can act as:

- **FSM actors** (e.g., `TransducerView`): Host state machines, manage effects, coordinate business logic.
- **Adapters or injectors**: Wire dependencies, inject environments, bridge layers.
- **Coordinators**: Compose child views, manage navigation and state flow.
- **Traditional UI components**: Render pixels and handle user interaction.

This flexibility means that the architectural role of a SwiftUI view is determined by its responsibilities, not its type. Oak leverages this to keep business logic, state management, and composition declarative and testable.

## Module Roles (Quick Reference)

- **Injector (App):** Composes implementations and sets environment values. One per app.
- **Feature / Consumer (Scenes/*):** Owns domain types, transducer, views, and the public port (e.g. `ComicsEnv`).
- **Service / Adapter (Services/*):** Implements the feature port, maps DTOs → domain, and depends on provider APIs.
- **Provider / API (API/*):** DTOs and thin HTTP client wrappers.
- **Infra (HTTPClient, Persistence):** Low-level, stable code.
- **Common:** Tiny shared UI/helpers (keep minimal).
- **Tests / Mocks:** Test-only helpers and mock ports.

## Horizontal and Vertical Separation

- **Horizontal:** Many feature modules (e.g., Scenes/Comics, Scenes/Favourites, ...). Each feature is independent and owns its port.
- **Vertical:** Layers from App → Scenes → Services → API → HTTPClient. Features declare the port; adapters implement it (dependency inversion).

## Naming Conventions

> **Port name:** `<Feature>Env` or `<Feature>SideEffectsAPI` (keep small, all functions `@Sendable`).
> **Transducer alias:** `typealias Env = <Feature>Env` inside the transducer for ergonomics.
> **Factories:** Provide `static var live` and `static var mock` on the port for easy wiring and tests.

## Example (Comics as illustration)

```swift
// Feature port (replace Comics with your feature name)
public struct ComicsEnv {
  public var loadComic: @Sendable (Int) async throws -> Comic
  public var loadActualComic: @Sendable () async throws -> Comic
}

// Transducer implementation
extension Comics {
  enum Transducer: EffectTransducer {
    typealias Env = ComicsEnv
    // ... use Env in Effects
  }
}

// Adapter factory for App injector
// .environment(\.comicsEnv, ComicsEnv.live)
```

## Dependency Inversion Diagram

Dependency inversion: features declare ports, adapters implement them. Arrows show static compile-time dependencies (->) and runtime injection (=>).

Below is an ASCII diagram showing modules and runtime wiring. Arrows show static compile-time dependencies (->) and runtime injection (=>). The diagram highlights dependency inversion: features declare ports, adapters implement them.

```
   +-----------------+
   |      App        |  Injector / composition
   +--------+--------+
      |
      |  => (runtime: injects `ComicsEnv` implementation)
      V
    +----------------+   +----------------+   +----------------+
    | Scenes/Comics  |   | Scenes/Faves   |   | Scenes/Other   |   <-- feature modules (declare ports like `ComicsEnv`)
    | - Transducer   |   | - Transducer   |   | - Transducer   |
    | - Views        |   | - Views        |   | - Views        |
    +-------+--------+   +-------+--------+   +-------+--------+
   ^                    ^                    ^
   |                    |                    |
   |   (compile-time)   |                    |
   |   Services/*       |                    |
 +----------+--------------------+--------------------+----------+
 |          Services / Adapters (implement feature ports)        |
 |  e.g. Services/Comics  -> implements `ComicsEnv` and therefore   |
 |  has a static dependency on `Scenes/Comics` for domain types    |
 +----------------+----------------+----------------+-------------+
   |                |                |
   V                V                V
      +------+         +--------+       +--------+
      |  API |  -> DTOs|HTTPClient|  -> low-level infra
      +------+         +--------+       +--------+

Legend:
-> static compile-time dependency
=> runtime injection (App composes adapter impls into feature ports via SwiftUI environment)

Note: Services implement the port declared by Scenes; this inverts the classic dependency arrow and keeps high-level feature logic independent of low-level details.
```

## Best Practices Checklist

- Keep the Side Effects API (port) small and domain-focused.
- Implement adapters per feature; avoid monolithic service modules.
- Avoid leaking provider details into features; keep DTOs in API modules.
- Always test pure state transitions and effect integration with mocks.
- Use the injector for composition only; features should not import adapters directly.

## References

- [Oak Framework Documentation](https://github.com/couchdeveloper/Oak)
- [SwiftUI Environment](https://developer.apple.com/documentation/swiftui/environmentvalues)
- [Clean Architecture](https://8thlight.com/blog/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/)


## Dependency Inversion Details

Dependency inversion is applied only in the Side Effects API. It's is achieved by having each feature declare a small Side Effects API struct (the public port, e.g. `ComicsEnv`). The transducer aliases this to `Env` for ergonomic use in effects. Effects call methods on this API to perform I/O, and adapters implement the API, mapping provider DTOs to domain types. The App (injector) wires concrete implementations into the environment at runtime.

This pattern keeps features decoupled and testable, allows easy swapping of implementations (mock, local, network), and minimizes compile-time coupling. For details, see the diagram and code examples above.

## Navigation as State

Navigation is treated as application state. Transducers produce state that drives views and navigation. Because SwiftUI navigation is declarative (views are functions of state), using transducers to produce navigation state keeps navigation logic close to the feature logic and under the same testable, event-driven model.

## Runtime flow (sequence)

1. `App` / `MainView` sets up SwiftUI and injects a `ComicsSideEffectsAPI` into the environment with `ComicsServices` functions.
2. `Scenes.Comics.Views.SceneView` reads `@Environment(\.comicsSideEffectsAPI)` and starts a `TransducerView` with the `Comics.Transducer` type and the provided Side Effects API instance.
3. `TransducerView` runs the transducer. When the transducer emits an Effect that calls `sideEffects.loadComic`, the injected function executes (a `Services` function), which uses `API`/`HTTPClient` to fetch data.
4. Results flow back into the transducer via `input.send(.didCompleteLoading(...))` and the view updates.


## Notes, rationale and best-practices

- Keep the Side Effects API small and purpose-built: only the functions the feature needs.
- Put adapter/glue code into `Services` so features stay framework-agnostic and easy to test.
- Use SwiftUI's environment for injection when the lifetime and composition of services is tied to the view hierarchy. The injector is just another SwiftUI view and can live in `App` or in a small infrastructure module.
- Effects model Request/Response naturally: an Effect performs async work via the Side Effects API instance (e.g. `sideEffects`), then sends result events back into the transducer.
- Navigation belongs in state. Use the transducer to drive navigation state and let SwiftUI render navigation accordingly.

## Principles — when this framework works best

1. Feature as a pure system (recommended)
  - Treat a feature (the transducer + its feature-level types) as a pure, deterministic system: it receives events and produces state and outputs. Any interaction with the outside world (network, disk, system APIs, current time, randomness, etc.) should happen inside Effects that call the provided Side Effects API (the transducer implementation commonly aliases this to `Env`).
  - Why: keeping the feature pure makes it trivially testable (unit tests can exercise state transitions synchronously), deterministic (no hidden side-effects), and ideal for SwiftUI Previews. Even seemingly innocuous queries (e.g., "what is the current date?") should be supplied via the Side Effects API so the feature remains deterministic under test.

2. Explicit effects surface dependencies
  - Side effects are explicit objects (Effects) that depend on the Side Effects API. This makes all external dependencies explicit in the module boundary and prevents accidental coupling to providers or platform APIs.

3. Keep Side Effects API small and domain-focused
  - The fewer and simpler the functions crossing the boundary, the less compile-time coupling there is between feature and provider layers. Map provider DTOs inside adapter modules so domain types are owned by the feature.

4. Use the injector for composition only
  - Let the injector compose provider implementations into Side Effects API instances. The injector may import many providers/adapters; features should not.

Small checklist for feature authors
 - Keep your Side Effects API minimal and domain-typed.
 - Implement network/persistence mapping in Service/Adapter modules.
 - Avoid importing providers in feature modules — use the injector to wire implementations.
 - Write unit tests for pure state transitions and a small number of integration tests for Effects.

## Where to look in the sample

- `Comics.Transducer` — `Scenes/Comics/Sources/Comics/Transducer.swift`
- `Comics.Views.SceneView` — `Scenes/Comics/Sources/Comics/Views.swift`
- `ComicsServices` — `Services/Sources/Services/Comics/ComicsServices.swift`
- `ComicAPI` + DTOs — `API/Sources/API/ComicAPI.swift` and DTO files
- `HttpClient` — `HTTPClient/Sources/HTTPClient/HTTPClient.swift`
- `App` injector — `App/App.swift` and `Scenes/Main/Sources/Main/ComicApp.swift` (contains `MainView` and environment wiring)
