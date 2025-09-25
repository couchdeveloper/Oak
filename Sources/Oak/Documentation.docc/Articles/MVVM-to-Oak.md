# Migrating from MVVM to Oak

A practical guide for converting MVVM ViewModels to Oak's state machine approach, with side-by-side comparisons and migration strategies.

## Understanding the Differences

### MVVM Approach

MVVM relies on observable properties and imperative state updates:

```swift
class DataListViewModel: ObservableObject {
    @Published var items: [DataItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showingError = false
    
    func loadData() {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        dataService.fetchItems { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let items):
                    self?.items = items
                case .failure(let error):
                    self?.error = error
                    self?.showingError = true
                }
            }
        }
    }
    
    func dismissError() {
        showingError = false
        error = nil
    }
}
```

### Oak Approach

Oak models the same functionality as explicit states and transitions:

```swift
enum DataListTransducer: EffectTransducer {
    enum State: NonTerminal {
        case idle
        case loading
        case loaded([DataItem])
        case error(Error)
    }
    
    enum Event {
        case loadData
        case dataLoaded([DataItem])
        case loadFailed(Error)
        case dismissError
    }
    
    struct Env: Sendable {
        var dataService: @Sendable () async throws -> [DataItem]
    }
    
    static var initialState: State { .idle }
    
    static func update(_ state: inout State, event: Event) -> Effect? {
        switch (state, event) {
        case (.idle, .loadData), (.error, .loadData):
            state = .loading
            return .loadData
            
        case (.loading, .dataLoaded(let items)):
            state = .loaded(items)
            return nil
            
        case (.loading, .loadFailed(let error)):
            state = .error(error)
            return nil
            
        case (.error, .dismissError):
            state = .idle
            return nil
            
        default:
            return nil
        }
    }
    
    static func loadDataEffect() -> Effect {
        Effect { env, input in
            do {
                let items = try await env.dataService()
                try input.send(.dataLoaded(items))
            } catch {
                try input.send(.loadFailed(error))
            }
        }
    }
}
```

## Key Differences Explained

### State Representation

**MVVM**: Multiple boolean flags and optional properties can create invalid combinations:
- `isLoading = true` and `error != nil` (loading with error?)
- `items.isEmpty` and `isLoading = false` (loaded but empty?)

**Oak**: Single enum state prevents invalid combinations:
- `.loading` means definitely loading, no data, no error
- `.loaded([])` means successfully loaded empty data
- `.error(Error)` means definitely failed, no partial data

### State Updates

**MVVM**: Imperative updates scattered across methods:
```swift
self?.isLoading = false  // Could be called from multiple places
self?.error = error      // Might conflict with other updates
```

**Oak**: Centralized, pure state transitions:
```swift
// All state changes happen in one place with explicit rules
static func update(_ state: inout State, event: Event) -> Effect?
```

### Error Handling

**MVVM**: Manual error state management:
```swift
self?.error = error
self?.showingError = true  // Separate flag for UI state
```

**Oak**: Error states are first-class:
```swift
case (.loading, .loadFailed(let error)):
    state = .error(error)  // Error is the state, not a property
```

## Migration Steps

### Step 1: Identify States

Look at your ViewModel's `@Published` properties and identify mutually exclusive states:

```swift
// MVVM properties
@Published var isLoading = false
@Published var items: [Item] = []
@Published var error: Error?

// Becomes Oak states
enum State {
    case idle
    case loading
    case loaded([Item])
    case error(Error)
}
```

### Step 2: Convert Methods to Events

Transform ViewModel methods into events:

```swift
// MVVM methods
func loadData() { ... }
func refresh() { ... }
func dismissError() { ... }

// Becomes Oak events
enum Event {
    case loadData
    case refresh
    case dismissError
    case dataLoaded([Item])
    case loadFailed(Error)
}
```

### Step 3: Move Async Operations to Effects

Extract async operations from methods into effects:

```swift
// MVVM async in method
func loadData() {
    dataService.fetchItems { result in
        // Handle result...
    }
}

// Oak effect
static func loadDataEffect() -> Effect {
    Effect { env, input in
        do {
            let items = try await env.dataService()
            try input.send(.dataLoaded(items))
        } catch {
            try input.send(.loadFailed(error))
        }
    }
}
```

### Step 4: Replace ViewModel with TransducerView

Convert your SwiftUI view from using `@StateObject` to `TransducerView`:

```swift
// MVVM view
struct DataListView: View {
    @StateObject private var viewModel = DataListViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                ErrorView(error: error) {
                    viewModel.dismissError()
                }
            } else {
                List(viewModel.items) { item in
                    ItemRow(item: item)
                }
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }
}

// Oak view
struct DataListView: View {
    @State private var state = DataListTransducer.initialState
    @Environment(\.dataListEnv) var env
    
    var body: some View {
        TransducerView(
            of: DataListTransducer.self,
            initialState: $state,
            env: env
        ) { state, input in
            Group {
                switch state {
                case .idle:
                    Button("Load Data") {
                        try? input.send(.loadData)
                    }
                    
                case .loading:
                    ProgressView()
                    
                case .loaded(let items):
                    List(items) { item in
                        ItemRow(item: item)
                    }
                    
                case .error(let error):
                    ErrorView(error: error) {
                        try? input.send(.dismissError)
                    }
                }
            }
        }
        .onAppear {
            if case .idle = state {
                try? input.send(.loadData)
            }
        }
    }
}
```

## Common Migration Patterns

### Loading States

**MVVM Pattern**:
```swift
@Published var isLoading = false
@Published var data: Data?
```

**Oak Pattern**:
```swift
enum State {
    case idle
    case loading
    case loaded(Data)
}
```

### Error Handling

**MVVM Pattern**:
```swift
@Published var error: Error?
@Published var showingError = false
```

**Oak Pattern**:
```swift
enum State {
    case error(Error, canRetry: Bool)
}

enum Event {
    case dismissError
    case retry
}
```

### Form Validation

**MVVM Pattern**:
```swift
@Published var email = ""
@Published var password = ""
@Published var emailError: String?
@Published var passwordError: String?
@Published var isValid = false
```

**Oak Pattern**:
```swift
enum State {
    case editing(email: String, password: String, validation: ValidationState)
    case submitting(email: String, password: String)
    case submitted
}

enum ValidationState {
    case valid
    case invalid([ValidationError])
}
```

## Benefits After Migration

### Compile-Time Safety

Oak prevents invalid state combinations that are possible in MVVM:

```swift
// MVVM: This is possible but invalid
viewModel.isLoading = true
viewModel.error = someError  // Loading AND error?

// Oak: This is impossible to represent
// States are mutually exclusive by design
```

### Predictable State Changes

Oak's pure functions make state changes predictable and testable:

```swift
// MVVM: Hard to test all state combinations
func testErrorHandling() {
    viewModel.isLoading = true
    // Simulate network error...
    // What if isLoading doesn't get set to false?
}

// Oak: Easy to test pure functions
func testErrorHandling() {
    var state = DataListTransducer.State.loading
    let effect = DataListTransducer.update(&state, event: .loadFailed(testError))
    XCTAssertEqual(state, .error(testError))
    XCTAssertNil(effect)
}
```

### Easier Debugging

State machines provide clear audit trails:

```swift
// Oak: State transitions are explicit
.idle → .loading (loadData event)
.loading → .error(NetworkError) (loadFailed event)
.error(NetworkError) → .idle (dismissError event)
```

## Migration Checklist

- [ ] Identify all possible states from `@Published` properties
- [ ] Convert ViewModel methods to events
- [ ] Extract async operations into effects
- [ ] Define environment for dependencies
- [ ] Replace `@StateObject` with `@State` and `TransducerView`
- [ ] Update SwiftUI view to use state-driven UI
- [ ] Add environment injection for effects
- [ ] Test state transitions in isolation
- [ ] Verify no invalid state combinations exist

The result is more predictable, testable, and maintainable code with stronger compile-time guarantees.