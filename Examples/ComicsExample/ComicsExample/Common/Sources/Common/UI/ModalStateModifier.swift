import SwiftUI

extension View {
    
    /// Presents modal UI driven by a `States.ViewState`, wiring a sheet, an alert, and a busy overlay.
    ///
    /// This modifier observes the provided `state` to:
    /// - Present a sheet when `state.presentation` is non-nil.
    /// - Present an alert when `state.isFailure` is true (using `state.failure`).
    /// - Show a blocking progress overlay while `state.isBusy` is true.
    ///
    /// - Generic Parameters:
    ///   - State: A type conforming to `States.ViewState` that exposes `Presentation`, `Failure`, and state flags.
    ///   - SheetContent: The view type used for the sheet's content.
    ///   - AlertContent: The view type used for the alert's message content.
    ///
    /// - Parameters:
    ///   - state: The current view state that drives sheet, alert, and busy presentation.
    ///   - sheet: A builder that returns the sheet content for a given `State.Presentation` value.
    ///   - alert: A builder that returns the alert message content for a given `State.Failure` value.
    ///
    /// - Returns: A view that manages sheet, alert, and busy overlay presentation based on `state`.
    @ViewBuilder
    public func modal<
        State: States.ViewState,
        SheetContent: View,
        AlertContent: View
    >(
        state: State,
        sheet: @escaping (State.Presentation) -> SheetContent,
        alert: @escaping (State.Failure) -> AlertContent
    ) -> some View {
        modifier(ModalStateModifier(
            state: state,
            sheet: sheet,
            alert: alert
        ))
    }
    
}


private struct ModalStateModifier<
    State: States.ViewState,
    SheetContent: View,
    AlertContent: View
>: ViewModifier {
    @SwiftUI.State private var presentation: State.Presentation?
    @SwiftUI.State private var isAlertPresented: Bool = false

    let state: State
    let sheet: (State.Presentation) -> SheetContent
    let alert: (State.Failure) -> AlertContent

    func body(
        content: Content,
    ) -> some View {
        content
            .sheet(
                item: $presentation,
                onDismiss: { /* no-op */ },
                content: { presentation in
                    sheet(presentation)
                }
            )
            .onChange(of: state.presentation?.id, initial: true) { _, _ in
                presentation = state.presentation
            }
            .alert(
                "Error",
                isPresented: $isAlertPresented,
                presenting: state.failure,
                actions: { _ in
                    Button("OK", action: { /* no-op */ })
                }, message: { error in
                    alert(error)
                }
            )
            .onChange(of: state.isFailure, initial: true) { _, newValue in
                isAlertPresented = newValue
            }
            .overlay(alignment: .center) {
                if state.isBusy {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                        ProgressView()
                            .tint(.accentColor)
                            .scaleEffect(1.1)
                    }
                    .transition(.opacity)
                }
            }
            .disabled(state.isBusy)
    }
}

