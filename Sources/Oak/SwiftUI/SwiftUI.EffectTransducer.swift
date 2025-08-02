#if canImport(SwiftUI)
import SwiftUI

extension EffectTransducer {
    
    /// Runs a transducer with an observable state whose update function has the signature
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function and the `output` closure are isolated by the given Actor (a `SwiftUI.View`),
    /// that can be explicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function can be designed to optionally return an _effect_. Effects are invoked by
    /// the transducer which usually run within a Swift Task which is managed by the transuder. The tasks
    /// operation can emit events which will be feed back to the transducer. The managed tasks can
    /// be explicitly cancelled in the update function. When the transducer reaches a terminal state _all_
    /// running tasks will be cancelled.
    ///
    /// The update function must at least run once, in order to successfully execute the transducer.
    /// The initial state must not be a terminal state.
    ///
    /// - Parameters:
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. Its usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
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
        env: Env,
        output: some Subject<Output>,
        isolated: isolated any Actor = #isolation,
    ) async throws -> Output where TransducerOutput == (Self.Effect?, Output) {
        try await run(
            storage: binding,
            proxy: proxy,
            env: env,
            output: output,
            systemActor: isolated
        )
    }
    
    /// Runs a transducer with an observable state whose update function has the signature
    /// `(inout State, Event) -> Effect?`.
    ///
    /// The update function and the `output` closure are isolated by the given Actor (a `SwiftUI.View`),
    /// that can be explicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function can be designed to optionally return an _effect_. Effects are invoked by
    /// the transducer which usually run within a Swift Task which is managed by the transuder. The tasks
    /// operation can emit events which will be feed back to the transducer. The managed tasks can
    /// be explicitly cancelled in the update function. When the transducer reaches a terminal state _all_
    /// running tasks will be cancelled.
    ///
    /// The update function must at least run once, in order to successfully execute the transducer.
    /// The initial state must not be a terminal state.
    ///
    /// - Parameters:
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. Its usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    ///   transducer when setting its initial state.
    ///   - isolated: The actor where the `update` function will run on and where the state
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    public static func run(
        binding: Binding<State>,
        proxy: Proxy,
        env: sending Env,
        isolated: isolated any Actor = #isolation
    ) async throws where TransducerOutput == Self.Effect?, Output == Void {
        try await run(
            storage: binding,
            proxy: proxy,
            env: env,
            systemActor: isolated
        )
    }

    /// Runs a transducer with an observable state whose update function has the signature
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function is isolated by the given Actor (a `SwiftUI.View`),
    /// that can be explicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function can be designed to optionally return an _effect_. Effects are invoked by
    /// the transducer which usually run within a Swift Task which is managed by the transuder. The tasks
    /// operation can emit events which will be feed back to the transducer. The managed tasks can
    /// be explicitly cancelled in the update function. When the transducer reaches a terminal state _all_
    /// running tasks will be cancelled.
    ///
    /// The update function must at least run once, in order to successfully execute the transducer.
    /// The initial state must not be a terminal state.
    ///
    /// - Parameters:
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. Its usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
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
        env: sending Env,
        isolated: isolated any Actor = #isolation
    ) async throws -> Output where TransducerOutput == (Self.Effect?, Output) {
        try await run(
            storage: binding,
            proxy: proxy,
            env: env,
            output: NoCallback<Output>()
        )
    }
}

#endif // canImport(SwiftUI)
