# TransducerView: Complete Reference

TransducerView is Oak's primary SwiftUI integration component, providing lifecycle-aware state machine management with reactive updates and environment injection.

## Basic Usage

TransducerView manages a transducer's complete lifecycle within SwiftUI's view system:

```swift
struct CounterView: View {
    @State private var counterState = Counter.initialState
    
    var body: some View {
        TransducerView(
            of: Counter.self,
            initialState: $counterState
        ) { state, input in
            VStack {
                Text("Count: \(state.count)")
                
                Button("Increment") {
                    try? input.send(.increment)
                }
            }
        }
    }
}
```

## Lifecycle Management

### Automatic Startup

TransducerView automatically starts the transducer when the view appears:

- Creates the transducer actor
- Begins processing events
- Starts any initial effects

### State Synchronization

Changes to the transducer's internal state automatically update the SwiftUI view:

```swift
// State changes trigger view updates
TransducerView(...) { state, input in
    switch state {
    case .idle:
        IdleView()
    case .loading:
        ProgressView() // Automatically shown when state changes
    case .loaded(let data):
        DataView(data: data)
    }
}
```

### Cleanup

When the view disappears, TransducerView:

- Cancels all running effects
- Stops the transducer actor
- Releases resources

## Environment Injection

### Basic Environment Setup

For EffectTransducers, provide environment through SwiftUI's environment system:

```swift
// Define environment entry
extension EnvironmentValues {
    @Entry var dataLoaderEnv: DataLoader.Env = .production
}

// Provide environment in parent view
struct ContentView: View {
    var body: some View {
        DataView()
            .environment(\.dataLoaderEnv, .production)
    }
}

// Use environment in TransducerView
struct DataView: View {
    @State private var state = DataLoader.initialState
    @Environment(\.dataLoaderEnv) var env
    
    var body: some View {
        TransducerView(
            of: DataLoader.self,
            initialState: $state,
            env: env
        ) { state, input in
            // View content
        }
    }
}
```

### Environment Variants

Create different environments for different contexts:

```swift
extension DataLoader.Env {
    static var production: Self {
        Self(
            dataService: RealDataService.shared.fetchData,
            logger: OSLog.default.log
        )
    }
    
    static var preview: Self {
        Self(
            dataService: { PreviewData.sampleItems },
            logger: { _ in }
        )
    }
    
    static var test: Self {
        Self(
            dataService: { MockData.items },
            logger: { print($0) }
        )
    }
}
```

## Output Handling

### Basic Output Handling

Handle transducer outputs for parent communication:

```swift
struct ParentView: View {
    @State private var childState = ChildTransducer.initialState
    @State private var parentMessage = ""
    
    var body: some View {
        VStack {
            Text(parentMessage)
            
            TransducerView(
                of: ChildTransducer.self,
                initialState: $childState
            ) { state, input in
                ChildContent(state: state, input: input)
            } output: { result in
                parentMessage = "Child completed with: \(result)"
            }
        }
    }
}
```

### Complex Output Patterns

Use outputs to coordinate between multiple transducers:

```swift
struct CoordinatedView: View {
    @State private var authState = AuthTransducer.initialState
    @State private var dataState = DataTransducer.initialState
    @Environment(\.authEnv) var authEnv
    @Environment(\.dataEnv) var dataEnv
    
    var body: some View {
        VStack {
            TransducerView(
                of: AuthTransducer.self,
                initialState: $authState,
                env: authEnv
            ) { state, input in
                AuthView(state: state, input: input)
            } output: { authResult in
                // Forward auth result to data transducer
                if case .authenticated(let token) = authResult {
                    // Update data environment with auth token
                    // Or send event to data transducer
                }
            }
            
            TransducerView(
                of: DataTransducer.self,
                initialState: $dataState,
                env: dataEnv
            ) { state, input in
                DataView(state: state, input: input)
            }
        }
    }
}
```

## Advanced Integration Patterns

### State-Driven Navigation

Use transducer state to drive navigation decisions:

```swift
struct NavigationCoordinator: View {
    @State private var coordinatorState = NavigationTransducer.initialState
    
    var body: some View {
        TransducerView(
            of: NavigationTransducer.self,
            initialState: $coordinatorState
        ) { state, input in
            NavigationStack {
                switch state {
                case .home:
                    HomeView()
                    
                case .profile(let user):
                    ProfileView(user: user)
                    
                case .settings:
                    SettingsView()
                    
                case .modal(let content):
                    HomeView()
                        .sheet(isPresented: .constant(true)) {
                            ModalView(content: content)
                        }
                }
            }
        }
    }
}
```

### Modal Management

Handle sheet and alert presentation through state:

```swift
enum AppState {
    case idle
    case showingSheet(SheetContent)
    case showingAlert(AlertContent)
}

struct AppView: View {
    @State private var appState = AppTransducer.initialState
    
    var body: some View {
        TransducerView(
            of: AppTransducer.self,
            initialState: $appState
        ) { state, input in
            ContentView()
                .sheet(
                    isPresented: Binding(
                        get: { 
                            if case .showingSheet = state { return true }
                            return false
                        },
                        set: { if !$0 { try? input.send(.dismissSheet) } }
                    )
                ) {
                    if case .showingSheet(let content) = state {
                        SheetView(content: content)
                    }
                }
                .alert(
                    "Alert",
                    isPresented: Binding(
                        get: {
                            if case .showingAlert = state { return true }
                            return false
                        },
                        set: { if !$0 { try? input.send(.dismissAlert) } }
                    )
                ) {
                    Button("OK") {
                        try? input.send(.dismissAlert)
                    }
                }
        }
    }
}
```

### Form Integration

Integrate with SwiftUI forms and validation:

```swift
struct FormView: View {
    @State private var formState = FormTransducer.initialState
    
    var body: some View {
        TransducerView(
            of: FormTransducer.self,
            initialState: $formState
        ) { state, input in
            Form {
                Section("User Information") {
                    TextField("Name", text: Binding(
                        get: { state.name },
                        set: { try? input.send(.updateName($0)) }
                    ))
                    
                    TextField("Email", text: Binding(
                        get: { state.email },
                        set: { try? input.send(.updateEmail($0)) }
                    ))
                }
                
                Section("Validation") {
                    ForEach(state.validationErrors, id: \.self) { error in
                        Text(error.localizedDescription)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button("Submit") {
                        try? input.send(.submit)
                    }
                    .disabled(!state.isValid)
                }
            }
        }
    }
}
```

## Performance Considerations

### State Binding Optimization

TransducerView uses SwiftUI's built-in diffing for efficient updates:

```swift
// Good: State changes trigger minimal view updates
enum State {
    case loading(progress: Double)
    case loaded(itemCount: Int)  // Only count changes trigger updates
}

// Avoid: Large state copying
enum State {
    case loaded([HeavyDataItem])  // Full array comparison on every update
}
```

### View Composition

Break complex views into smaller components:

```swift
struct ComplexView: View {
    @State private var state = ComplexTransducer.initialState
    
    var body: some View {
        TransducerView(
            of: ComplexTransducer.self,
            initialState: $state
        ) { state, input in
            VStack {
                HeaderComponent(state: state.header, input: input)
                ContentComponent(state: state.content, input: input)
                FooterComponent(state: state.footer, input: input)
            }
        }
    }
}
```

## Testing TransducerView

### Preview Testing

Use preview environments for SwiftUI previews:

```swift
struct DataView_Previews: PreviewProvider {
    static var previews: some View {
        DataView()
            .environment(\.dataLoaderEnv, .preview)
    }
}
```

### Unit Testing

Test view integration using SwiftUI testing:

```swift
@Test
func testDataViewLoading() async throws {
    let view = DataView()
        .environment(\.dataLoaderEnv, .test)
    
    // Test initial state
    #expect(view.state == .idle)
    
    // Trigger loading
    try view.input.send(.load)
    
    // Verify loading state
    #expect(view.state == .loading)
}
```

## Common Patterns

### Parent as Coordinator

Use parent views to coordinate multiple child transducers:

```swift
struct CoordinatorView: View {
    @State private var authState = AuthTransducer.initialState
    @State private var mainState = MainTransducer.initialState
    
    var body: some View {
        if case .authenticated = authState {
            MainAppView(state: $mainState)
        } else {
            AuthView(state: $authState) { authResult in
                // Handle authentication success
                if case .success = authResult {
                    // Initialize main app state
                }
            }
        }
    }
}
```

### Conditional Rendering

Use state to conditionally render view hierarchies:

```swift
TransducerView(...) { state, input in
    switch state {
    case .loading:
        LoadingView()
        
    case .empty:
        EmptyStateView {
            try? input.send(.refresh)
        }
        
    case .error(let error):
        ErrorView(error: error) {
            try? input.send(.retry)
        }
        
    case .loaded(let data):
        DataListView(data: data)
    }
}
```

TransducerView provides a powerful, declarative way to integrate Oak's state machines with SwiftUI while maintaining clean separation of concerns and predictable behavior.