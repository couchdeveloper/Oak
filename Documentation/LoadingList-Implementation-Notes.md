# LoadingList Implementation Notes

## MVVM Implementation Issues & Solutions

### Issue: Sheet Presentation Loop

**Problem Encountered:**
The MVVM implementation experienced a sheet presentation loop where the modal would appear and immediately dismiss repeatedly.

**Root Causes Identified:**

1. **Reactive Feedback Loop**: Using computed `Binding` with `@Published` dependencies
2. **Multiple State Sources**: Having both `sheet` model and `isSheetPresented` boolean
3. **Complex Dependencies**: `@Published` properties that depend on each other
4. **ViewModel-Managed Sheet State**: Sheet presentation controlled by ViewModel properties

**Original Problematic Code:**
```swift
// ViewModel managing sheet state
@Published var presentSheet = false
@Published var sheetTitle = "Load Data"
@Published var sheetInputText = "sample"

// Complex reactive dependencies
var isSheetPresented: Binding<Bool> {
    Binding(
        get: { self.sheet != nil },
        set: { if !$0 { self.sheet = nil } }
    )
}
```

**Final Solution Implemented:**
```swift
// View-owned sheet state (no ViewModel involvement)
struct ContentView: View {
    @ObservedObject var viewModel: LoadingListViewModel
    @State private var showSheet = false  // View owns this
    @State private var inputText = "sample"  // View owns this
    
    // Simple boolean-based presentation
    .sheet(isPresented: $showSheet) {
        InputSheetView(
            inputText: $inputText,
            onCommit: { parameter in
                showSheet = false  // View controls dismissal
                viewModel.startLoading(with: parameter)
            },
            onCancel: {
                showSheet = false  // View controls dismissal
            }
        )
    }
}
```

### Key Solution Principles

1. **Separation of Concerns**: View owns UI state, ViewModel owns business logic
2. **No ViewModel Sheet Management**: ViewModel doesn't control sheet presentation
3. **Simplified ViewModel**: Only essential `@Published` properties
4. **Direct View State**: `@State` properties for UI-only concerns

### Comparison with Oak Implementation

The Oak state machine approach avoids these issues entirely by:
- **Single State Source**: All related state is part of one atomic state value
- **Explicit Transitions**: State changes are explicit and predictable
- **No Reactive Dependencies**: Pure functions prevent feedback loops
- **Declarative Approach**: State is what it is, not computed from other reactive properties

### Final Working Implementation

**ViewModel (Simplified):**
```swift
@MainActor
class LoadingListViewModel: ObservableObject {
    @Published var data: DataModel?
    @Published var isLoading = false
    @Published var error: ErrorModel?
    
    // Computed properties (not @Published)
    var isEmpty: Bool {
        return data == nil && !isLoading && error == nil
    }
    
    // Simple action methods
    func startLoading(with parameter: String) { ... }
    func cancelLoading() { ... }
    func dismissError() { ... }
}
```

**View (Controls Sheet):**
```swift
struct ContentView: View {
    @ObservedObject var viewModel: LoadingListViewModel
    @State private var showSheet = false
    @State private var inputText = "sample"
    
    // View handles all sheet logic
}
```

### Performance Notes

- **MVVM**: Requires careful separation of View and ViewModel responsibilities
- **Oak**: Single state updates prevent any reactive cycles
- **Testing**: Simplified ViewModel is easier to test than reactive ViewModel state

## Learning Summary

The key insight is that **not all UI state should be managed by the ViewModel**. Sheet presentation is a UI concern that can be handled by the View itself, while the ViewModel focuses purely on business logic and data state.

This demonstrates why Oak's approach is powerful - it forces you to think about state holistically rather than trying to coordinate multiple reactive properties.