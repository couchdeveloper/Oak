#if canImport(SwiftUI)
import SwiftUI

extension Transducer {
    
    /// Runs a transducer with an observable state whose update function has the signature
    /// `(inout State, Event) -> Output`.
    ///
    /// The update function and the `output` closure are isolated by the given Actor (a `SwiftUI.View`),
    /// that can be explicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function must at least run once, in order to successfully execute the transducer.
    /// The initial state must not be a terminal state.
    ///
    /// - Parameters:
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. Its usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - output: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces. The client uses a type where it can react on the given outputs.
    ///   - isolated: The actor where the `update` function will run on and where the state
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run(
        binding: Binding<State>,
        proxy: Proxy,
        output: some Subject<Output>,
        isolated: isolated any Actor = #isolation,
    ) async throws -> Output {
        try await run(
            storage: binding,
            proxy: proxy,
            output: output,
            systemActor: isolated
        )
    }

    /// Runs a transducer with an observable state whose update function has the signature
    /// `(inout State, Event) -> Output`.
    ///
    /// The update function is isolated by the given Actor (a `SwiftUI.View`),
    /// that can be explicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function must at least run once, in order to successfully execute the transducer.
    /// The initial state must not be a terminal state.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. Its usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run(
        binding: Binding<State>,
        proxy: Proxy,
        isolated: isolated any Actor = #isolation
    ) async throws -> Output {
        try await run(
            storage: binding,
            proxy: proxy,
            output: NoCallback<Output>(),
        )
    }
    
    /// Runs a transducer with an observable state whose update function has the signature
    /// `(inout State, Event) -> Void`.
    ///
    /// The update function is isolated by the given Actor (a `SwiftUI.View`),
    /// that can be explicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function must at least run once, in order to successfully execute the transducer.
    /// The initial state must not be a terminal state.
    ///
    /// - Parameters:
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. Its usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - isolated: The actor where the `update` function will run on and where the state
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    public static func run(
        binding: Binding<State>,
        proxy: Proxy,
        isolated: isolated any Actor = #isolation,
    ) async throws where Output == Void {
        try await run(
            storage: binding,
            proxy: proxy,
            output: NoCallback<Void>(),
        )
    }

}

#endif // canImport(SwiftUI)
