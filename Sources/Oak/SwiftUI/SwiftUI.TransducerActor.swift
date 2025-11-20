#if canImport(SwiftUI)
import SwiftUI

// MARK: - Where Transducer: Oak.Transducer, Output == Void
extension TransducerActor where Self: View, Content: View {
    /// Initialises a _transducer actor_ that runs a transducer with an update function that has the
    /// signature `(inout State, Event) -> Void`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// destroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The underlying storage of the state value, a `SwiftUI.Binding`.
    ///   The initial state is given by the current state value.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the
    ///   actor creates one.
    ///   - completion: An optional completion handler which will be called once when the transducer
    ///   finishes, providing a `Result` that contains either the successful output value or
    ///   an error if the transducer failed.
    ///   - content: A `@ViewBuilder` closure which takes the current state and the input as
    ///   parameters and returns a `SwiftUI.View`.
    ///
    /// ## Examples
    ///
    /// ### Using a TransducerView
    ///
    /// Given a transducer, `MyUseCase`, that conforms to `Transducer`, a transducer view can be
    /// created by using one of the initialiser overloads. This initialiser uses a `SwiftUI.Binding` as
    /// the source of the state and the initial state value for the transducer.
    ///
    ///```swift
    /// struct ContentView: View {
    ///     @State private var state: MyUseCase.State = .init()
    ///     var body: some View {
    ///         TransducerView(
    ///             of: MyUseCase.self,
    ///             initialState: $state
    ///         ) {
    ///             content: { state, input in
    ///                 GreetingView(
    ///                     greeting: state.greeting,
    ///                     send: { try input.send($0) }
    ///                 )
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    /// The below `GreetingView` view shows how to compose a content view. This view is
    /// also completely decoupled from transducer symbols.
    /// ```swift
    /// struct GreetingView: View {
    ///     let greeting: String
    ///     let send: (Event) throws -> Void
    ///
    ///     var body: some View {
    ///         VStack {
    ///             Text(greeting)
    ///         }
    ///         Button("Submit") {
    ///             send(.submit)
    ///         }
    ///     }
    /// }
    /// ```
    /// Each content view should have a _state_ constant and a `send` function. The state will
    /// change whenever the transducer produces a new state. The send function is used by the
    /// view to send user's intents (aka events) to the transducer.
    ///
    /// Basically, a content view should be _a function of state_, i.e. it itself performs no logic. This
    /// makes sense, since there's the transducer which solely exists to perform this computation.
    /// A view may only manages its own private state when it is invariant of the given logic defined
    /// by the transducer.
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: StateInitialising,
        proxy: Proxy? = nil,
        completion: Completion? = nil,
        @ViewBuilder content: @escaping (State, Input) -> Content
    ) where Transducer: Oak.Transducer, Output == Void {
        self.init(
            initialState: initialState,
            proxy: proxy,
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        _ = try await Transducer.run(
                            storage: storage,
                            proxy: proxy ?? Proxy(),
                            output: NoCallback(),
                            systemActor: systemActor
                        )
                        result = .success(Void())
                    } catch {
                        result = .failure(error)
                    }
                    completion?.completed(with: result)
                }
            },
            content: content
        )
    }

    /// Initialises a _transducer actor_ that runs a transducer with an update function that has the
    /// signature `(inout State, Event) -> Output`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// destroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The underlying storage of the state value, a `SwiftUI.Binding`.
    ///   The initial state is given by the current state value.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the
    ///   actor creates one.
    ///   - output: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///   - content: A `@ViewBuilder` closure which takes the current state and the input as
    ///   parameters and returns a `SwiftUI.View`.
    ///
    /// ## Examples
    ///
    /// ### Using a TransducerView
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: StateInitialising,
        proxy: Proxy? = nil,
        output: sending some Subject<Output>,
        completion: Completion? = nil,
        @ViewBuilder content: @escaping (State, Input) -> Content
    ) where Transducer: Oak.Transducer {
        self.init(
            initialState: initialState,
            proxy: proxy,
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        let outputValue = try await Transducer.run(
                            storage: storage,
                            proxy: proxy ?? Proxy(),
                            output: output,
                            systemActor: systemActor
                        )
                        result = .success(outputValue)
                    } catch {
                        result = .failure(error)
                    }
                    completion?.completed(with: result)
                }
            },
            content: content
        )
    }
}

// MARK: - Where Transducer: Oak.Transducer
extension TransducerActor where Self: View, Content: View {
    /// Initialises a _transducer actor_ that runs a transducer with an update function that has the
    /// signature `(inout State, Event) -> Output`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// destroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The underlying storage of the state value, a `SwiftUI.Binding`.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the
    ///   actor creates one.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///   - content: A `@ViewBuilder` closure which takes the current state and the input as
    ///   parameters and returns a `SwiftUI.View`.
    ///
    /// ## Examples
    ///
    /// ### Using a TransducerView
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: StateInitialising,
        proxy: Proxy? = nil,
        completion: Completion? = nil,
        @ViewBuilder content: @escaping (State, Input) -> Content
    ) where Transducer: Oak.Transducer {
        self.init(
            of: type,
            initialState: initialState,
            proxy: proxy,
            output: NoCallback(),
            completion: completion,
            content: content
        )
    }
}

// MARK: - Transducer: Oak.EffectTransducer, Transducer.TransducerOutput == (Transducer.Effect?, Output)
extension TransducerActor where Self: View, Content: View {
    /// Initialises a _transducer actor_ that runs an effect transducer with an update function that has the
    /// signature `(inout State, Event) -> (Self.Effect?, Output)`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// destroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The underlying storage of the state value, a `SwiftUI.Binding`.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - output: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///   - content: A `@ViewBuilder` closure which takes the current state and the input as
    ///   parameters and returns a `SwiftUI.View`.
    ///
    /// ## Examples
    ///
    /// ### Using a TransducerView
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: StateInitialising,
        proxy: Proxy? = nil,
        env: Transducer.Env,
        output: sending some Subject<Output>,
        completion: Completion? = nil,
        @ViewBuilder content: @escaping (State, Input) -> Content
    )
    where
        Transducer: Oak.EffectTransducer,
        Transducer.TransducerOutput == (Transducer.Effect?, Output)
    {
        nonisolated(unsafe) let env = env  // TODO: have to silence compiler error: Sending 'env' risks causing data races
        // IMHO, the compiler's error is not justified: `env` will only ever be
        // mutated from `isolated`. And yes, it is allowed to mutated it, outside
        // of the system (being isolated), but since it's isolated we cannot get
        // data races. There might be potential *race conditions*, but this is
        // expected, and in some cases it is actually intended to mutate the
        // environment while the transducer is running.
        // Note: adding `sending` to the parameter `env` will also silence the
        // error. However IMHO, `sending` should not be a requirement.
        self.init(
            initialState: initialState,
            proxy: proxy,
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        let outputValue = try await Transducer.run(
                            storage: storage,
                            proxy: proxy ?? Proxy(),
                            env: env,
                            output: output,
                            systemActor: systemActor
                        )
                        result = .success(outputValue)
                    } catch {
                        result = .failure(error)
                    }
                    completion?.completed(with: result)
                }
            },
            content: content
        )
    }
}

// MARK: - Transducer: Oak.EffectTransducer, Transducer.TransducerOutput == (Transducer.Effect?, Output)
extension TransducerActor where Self: View, Content: View {
    /// Initialises a _transducer actor_ that runs an effect transducer with an update function that has the
    /// signature `(inout State, Event) -> (Self.Effect?, Output)`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// destroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The underlying storage of the state value, a `SwiftUI.Binding`.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///   - content: A `@ViewBuilder` closure which takes the current state and the input as
    ///   parameters and returns a `SwiftUI.View`.
    ///
    /// ## Examples
    ///
    /// ### Using a TransducerView
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: StateInitialising,
        proxy: Proxy? = nil,
        env: Transducer.Env,
        completion: Completion? = nil,
        @ViewBuilder content: @escaping (State, Input) -> Content
    )
    where
        Transducer: Oak.EffectTransducer,
        Transducer.TransducerOutput == (Transducer.Effect?, Output)
    {
        self.init(
            of: type,
            initialState: initialState,
            proxy: proxy,
            env: env,
            output: NoCallback(),
            completion: completion,
            content: content
        )
    }
}

// MARK: - Transducer: Oak.EffectTransducer, Transducer.TransducerOutput == Transducer.Effect?
extension TransducerActor where Self: View, Content: View {
    /// Initialises a _transducer actor_ that runs an effect transducer with an update function that has the
    /// signature `(inout State, Event) -> Self.Effect?`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// destroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The underlying storage of the state value, a `SwiftUI.Binding`.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///   - content: A `@ViewBuilder` closure which takes the current state and the input as
    ///   parameters and returns a `SwiftUI.View`.
    ///
    /// ## Examples
    ///
    /// ### Using a TransducerView
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: StateInitialising,
        proxy: Proxy? = nil,
        env: Transducer.Env,
        completion: Completion? = nil,
        @ViewBuilder content: @escaping (State, Input) -> Content
    )
    where
        Transducer: Oak.EffectTransducer, Transducer.TransducerOutput == Transducer.Effect?,
        Output == Void
    {
        nonisolated(unsafe) let env = env  // TODO: have to silence compiler error: Sending 'env' risks causing data races
        // IMHO, the compiler's error is not justified: `env` will only ever be
        // mutated from `isolated`. And yes, it is allowed to mutated it, outside
        // of the system (being isolated), but since it's isolated we cannot get
        // data races. There might be potential *race conditions*, but this is
        // expected, and in some cases it is actually intended to mutate the
        // environment while the transducer is running.
        // Note: adding `sending` to the parameter `env` will also silence the
        // error. However IMHO, `sending` should not be a requirement.
        self.init(
            initialState: initialState,
            proxy: proxy,
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        _ = try await Transducer.run(
                            storage: storage,
                            proxy: proxy ?? Proxy(),
                            env: env,
                            systemActor: systemActor
                        )
                        result = .success(Void())
                    } catch {
                        result = .failure(error)
                    }
                    completion?.completed(with: result)
                }
            },
            content: content
        )
    }
}
#endif
