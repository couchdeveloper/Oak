/// A type that incorporates a transducer and provides the storage and the isolation where it executes.
///
/// ## Overview
///
/// A transducer actor's responsibility is to setup the prerequisites for running a transducer, such as the
/// actual container of the state, the environment, the proxy and callbacks and also the isolation.
///
/// For example, SwiftUI views can conform to a transducer actor which enables them to leverage the power
/// of Oak transducers. A view provides the state, the proxy (and input) and it may react on the output.
/// A view which provides the state can also observe it and thus may also directly act on state. For example,
/// the transducer may set a state that indicates to show a sheet. That can be a "sheet item". The view just
/// renders the sheet when this sheet item is non-nil. This is an elegant way to combine presentation logic
/// and a given view machinery.
///
///
///## Building Hierarchies of Transducers
///
/// Now, the power of SwiftUI Views and their ability to compose and built hierarchies can be leveraged to
/// also built hierarchies of transducers. The transducer actor, i.e. the SwiftUI view, knowns how to present
/// sheets and it knows how to navigate to destination views. When these destination views also use
/// transducers, it just needs to wire them up, that is, connecting the output of the distination transducer with
/// the input of its own transducer in order to esablish a communication.
///
/// The protocol is designed to work seamlessly with SwiftUI views and types conforming to the `Observable`
/// protocol from the Observation framework, enabling reactive updates when the transducer's state changes.
///
/// A `TransducerActor` provides the state for the transducer and the isolation context in which it runs.
/// The extension functions require the state as a `Storage` argument. This also allows the concrete
/// transducer actor to receive shared state as a Storage itself. The `Oak.TransducerView` is an
/// example, which receives the state as a Binding from a parent view.
///
/// The Oak library provides two generic implementations of this protocol:
///
/// - **`TransducerView`**: A SwiftUI view that conforms to `TransducerActor`, enabling declarative UI
///   that automatically updates when the transducer's state changes.
/// - **`ObservableTransducer`**: A generic type conforming to the `Observable` protocol from the
///   Observation framework, providing reactive state management outside of SwiftUI contexts.
///
/// ## Usage Patterns
///
/// ### SwiftUI Integration
/// ```swift
/// struct MyView: View {
///     @State privat var state: MyUseCase.State = .init()
///     var body: some View {
///         TransducerView(
///             of: MyUseCase.self,
///             storage: $state
///          ) { state, input in
///             Text(state.message)
///             Button("Action") { try input.send(.userAction) }
///         }
///     }
/// }
/// ```
///
/// ### Observable Integration
/// ```swift
/// struct MyView: View {
///     @State privat var model = ObservableTransducer(of: MyUseCase.self)
///     var body: some View {
///         Text(model.message)
///         Button("Action") { try model.proxy.send(.userAction) }
///     }
/// }
/// ```
///
/// ## State Management Philosophy
///
/// The distinction between standalone transducers and `TransducerActor` implementations reflects different
/// architectural needs:
///
/// - **Standalone Transducers**: Provide strict encapsulation, ideal for business logic that doesn't need
///   external observation.
/// - **TransducerActor**: Provides controlled observation of state changes, essential for reactive UI patterns
///   and external system integration.
///
public protocol TransducerActor<Transducer> {
    typealias State = Transducer.State
    typealias Event = Transducer.Event
    typealias Output = Transducer.Output
    typealias Proxy = Transducer.Proxy
    typealias Input = Proxy.Input

    associatedtype Transducer: BaseTransducer
    associatedtype StateInitialising
    associatedtype Content
    associatedtype Storage: Oak.Storage<State>
    associatedtype Completion: Oak.Completable<Output, Error>

    var proxy: Proxy { get }

    /// Returns a transducer actor.
    ///
    /// > Warning: Do not call this initialiser directly. It's called internally by the other initialiser
    /// overloads.
    ///
    /// - Parameters:
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a `Result` that contains either the successful output value or
    ///   an error if the transducer failed.
    ///   - runTransducer: A closure which will be immediately called when the actor will be initialised.
    ///   It starts the transducer which runs in a Swift Task.
    ///   - content: A closure which takes the current state and the input as parameters and
    ///  returns a content. The content closure can be used to drive other components that
    ///  provide an interface and controls.
    ///
    init(
        initialState: StateInitialising,
        proxy: Proxy,
        completion: Completion?,
        runTransducer: @escaping (
            Storage,
            Proxy,
            Completion,
            isolated any Actor
        ) -> Task<Void, Never>,
        content: @escaping (State, Input) -> Content
    )

    /// Cancels the transducer.
    ///
    /// This forcibly terminates the running transducer task. The state will not be
    /// modified.
    ///
    /// If the transducer is not running, this method does nothing.
    func cancel()
}

// MARK: -

extension TransducerActor where StateInitialising == State {
    
    /// Initialises a _transducer actor_ that runs a transducer with an update function that has the
    /// signature `(inout State, Event) -> Void`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The intial state.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the
    ///   actor creates one.
    ///   - completion: An optional completion handler which will be called once when the transducer
    ///   finishes, providing a `Result` that contains either the successful output value or
    ///   an error if the transducer failed.
    ///   - content: A closure which takes the current state and the input as parameters and
    ///   returns a content. The content closure can be used to drive other components that
    ///   provide an interface and controls.
    ///
    /// ## Examples
    ///
    /// ### Using a TransducerView
    ///
    /// Given a transducer, `MyUseCase`, that conforms to `Transducer`, a transducer view can be
    /// created by passing in the _type_ of the transducer and the content view can be created in the
    /// traling closure as shown below:
    ///
    ///```swift
    /// struct ContentView: View {
    ///     var body: some View {
    ///         TransducerView(of: MyUseCase.self) {
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
        content: @escaping (State, Input) -> Content
    ) where Transducer: Oak.Transducer, Output == Void {
        self.init(
            initialState: initialState,
            proxy: proxy ?? Proxy(),
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        _ = try await Transducer.run(
                            storage: storage,
                            proxy: proxy,
                            output: NoCallback(),
                            systemActor: systemActor
                        )
                        result = .success(Void())
                    } catch {
                        result = .failure(error)
                    }
                    completion.completed(with: result)
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
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The intial state.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the
    ///   actor creates one.
    ///   - output: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///   - content: A closure which takes the current state and the input as parameters and
    ///  returns a content. The content closure can be used to drive other components that
    ///  provide an interface and controls.
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
        content: @escaping (State, Input) -> Content
    ) where Transducer: Oak.Transducer {
        self.init(
            initialState: initialState,
            proxy: proxy ?? Proxy(),
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        let outputValue = try await Transducer.run(
                            storage: storage,
                            proxy: proxy,
                            output: output,
                            systemActor: systemActor
                        )
                        result = .success(outputValue)
                    } catch {
                        result = .failure(error)
                    }
                    completion.completed(with: result)
                }
            },
            content: content
        )
    }
    
}

extension TransducerActor where StateInitialising == State {

    /// Initialises a _transducer actor_ that runs a transducer with an update function that has the
    /// signature `(inout State, Event) -> Output`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The intial state.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the
    ///   actor creates one.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///   - content: A closure which takes the current state and the input as parameters and
    ///  returns a content. The content closure can be used to drive other components that
    ///  provide an interface and controls.
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
        content: @escaping (State, Input) -> Content
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

extension TransducerActor where StateInitialising == State {
    
    /// Initialises a _transducer actor_ that runs an effect transducer with an update function that has the
    /// signature `(inout State, Event) -> (Self.Effect?, Output)`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The intial state.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - output: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///   - content: A closure which takes the current state and the input as parameters and
    ///  returns a content. The content closure can be used to drive other components that
    ///  provide an interface and controls.
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
        content: @escaping (State, Input) -> Content
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
            proxy: proxy ?? Proxy(),
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        let outputValue = try await Transducer.run(
                            storage: storage,
                            proxy: proxy,
                            env: env,
                            output: output,
                            systemActor: systemActor
                        )
                        result = .success(outputValue)
                    } catch {
                        result = .failure(error)
                    }
                    completion.completed(with: result)
                }
            },
            content: content
        )
    }
    
}

extension TransducerActor where StateInitialising == State {
    /// Initialises a _transducer actor_ that runs an effect transducer with an update function that has the
    /// signature `(inout State, Event) -> (Self.Effect?, Output)`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The intial state.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///   - content: A closure which takes the current state and the input as parameters and
    ///  returns a content. The content closure can be used to drive other components that
    ///  provide an interface and controls.
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
        content: @escaping (State, Input) -> Content
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

extension TransducerActor where StateInitialising == State {

    /// Initialises a _transducer actor_ that runs an effect transducer with an update function that has the
    /// signature `(inout State, Event) -> Self.Effect?`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The intial state.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///   - content: A closure which takes the current state and the input as parameters and
    ///  returns a content. The content closure can be used to drive other components that
    ///  provide an interface and controls.
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
        content: @escaping (State, Input) -> Content
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
            proxy: proxy ?? Proxy(),
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        _ = try await Transducer.run(
                            storage: storage,
                            proxy: proxy,
                            env: env,
                            systemActor: systemActor
                        )
                        result = .success(Void())
                    } catch {
                        result = .failure(error)
                    }
                    completion.completed(with: result)
                }
            },
            content: content
        )
    }
}


// MARK: -

extension TransducerActor where StateInitialising == State, Content == Never {

    /// Initialises a _transducer actor_ that runs an effect transducer with an update function that has the
    /// signature `(inout State, Event) -> (Self.Effect?, Output)`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The intial state.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - output: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///   - content: A closure which takes the current state and the input as parameters and
    ///  returns a content. The content closure can be used to drive other components that
    ///  provide an interface and controls.
    ///
    /// ## Examples
    ///
    /// ### Using an ObservableTransducer
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: StateInitialising,
        proxy: Proxy? = nil,
        env: Transducer.Env,
        output: sending some Subject<Output>,
        completion: Completion? = nil,
        content: @escaping (State, Input) -> Content
) where
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
            proxy: proxy ?? Proxy(),
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        let outputValue = try await Transducer.run(
                            storage: storage,
                            proxy: proxy,
                            env: env,
                            output: output,
                            systemActor: systemActor
                        )
                        result = .success(outputValue)
                    } catch {
                        result = .failure(error)
                    }
                    completion.completed(with: result)
                }
            },
            content: content
        )
    }

    /// Initialises a _transducer actor_ that runs an effect transducer with an update function that has the
    /// signature `(inout State, Event) -> (Self.Effect?, Output)`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The intial state.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///   - content: A closure which takes the current state and the input as parameters and
    ///  returns a content. The content closure can be used to drive other components that
    ///  provide an interface and controls.
    ///
    /// ## Examples
    ///
    /// ### Using an ObservableTransducer
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: StateInitialising,
        proxy: Proxy? = nil,
        env: Transducer.Env,
        completion: Completion? = nil,
        content: @escaping (State, Input) -> Content
    ) where
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

    /// Initialises a _transducer actor_ that runs an effect transducer with an update function that has the
    /// signature `(inout State, Event) -> Self.Effect?`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The intial state.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///   - content: A closure which takes the current state and the input as parameters and
    ///  returns a content. The content closure can be used to drive other components that
    ///  provide an interface and controls.
    ///
    /// ## Examples
    ///
    /// ### Using an ObservableTransducer
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: StateInitialising,
        proxy: Proxy? = nil,
        env: Transducer.Env,
        completion: Completion? = nil,
        content: @escaping (State, Input) -> Content
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
            proxy: proxy ?? Proxy(),
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Void, Error>
                    do {
                        try await Transducer.run(
                            storage: storage,
                            proxy: proxy,
                            env: env,
                            systemActor: systemActor
                        )
                        result = .success(Void())
                    } catch {
                        result = .failure(error)
                    }
                    completion.completed(with: result)
                }
            },
            content: content
        )
    }

}

extension TransducerActor where StateInitialising == State, Content == Never {

    /// Initialises a _transducer actor_ that runs a transducer with an update function that has the
    /// signature `(inout State, Event) -> Output`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - storage: The underlying storage of the state value. The type conforms to `Oak.Storage`.
    ///   It has a getter and a nonmutating setter. The intial state is given by the current state value.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - output: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///
    /// ## Examples
    ///
    /// ### Using an ObservableTransducer
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: StateInitialising,
        proxy: Proxy? = nil,
        output: sending some Subject<Output>,
        completion: Completion? = nil,
    ) where Transducer: Oak.Transducer {
        self.init(
            initialState: initialState,
            proxy: proxy ?? Transducer.Proxy(),
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        let outputValue = try await Transducer.run(
                            storage: storage,
                            proxy: proxy,
                            output: output,
                            systemActor: systemActor
                        )
                        result = .success(outputValue)
                    } catch {
                        result = .failure(error)
                    }
                    completion.completed(with: result)
                }
            },
            content: { _, _ in fatalError("No content") }
        )
    }

    /// Initialises a _transducer actor_ that runs a transducer with an update function that has the
    /// signature `(inout State, Event) -> Void`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - storage: The underlying storage of the state value. The type conforms to `Oak.Storage`.
    ///   It has a getter and a nonmutating setter. The intial state is given by the current state value.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///
    /// ## Examples
    ///
    /// ### Using an ObservableTransducer
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: State,
        proxy: Proxy? = nil,
        completion: Completion? = nil,
    ) where Transducer: Oak.Transducer, Output == Void {
        self.init(
            initialState: initialState,
            proxy: proxy ?? Transducer.Proxy(),
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        _ = try await Transducer.run(
                            storage: storage,
                            proxy: proxy,
                            output: NoCallback(),
                            systemActor: systemActor
                        )
                        result = .success(Void())
                    } catch {
                        result = .failure(error)
                    }
                    completion.completed(with: result)
                }
            },
            content: { _, _ in fatalError("No content") }
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
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - storage: The underlying storage of the state value. The type conforms to `Oak.Storage`.
    ///   It has a getter and a nonmutating setter. The intial state is given by the current state value.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///
    /// ## Examples
    ///
    /// ### Using an ObservableTransducer
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: StateInitialising,
        proxy: Proxy? = nil,
        completion: Completion? = nil,
    ) where Transducer: Oak.Transducer {
        self.init(
            initialState: initialState,
            proxy: proxy ?? Transducer.Proxy(),
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        let outputValue = try await Transducer.run(
                            storage: storage,
                            proxy: proxy,
                            output: NoCallback(),
                            systemActor: systemActor
                        )
                        result = .success(outputValue)
                    } catch {
                        result = .failure(error)
                    }
                    completion.completed(with: result)
                }
            },
            content: { _, _ in fatalError("No content") }
        )
    }

}

extension TransducerActor where StateInitialising == State, Content == Never {

    /// Initialises a _transducer actor_ that runs an effect transducer with an update function that has the
    /// signature `(inout State, Event) -> (Self.Effect?, Output)`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The intial state.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - output: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///
    /// ## Examples
    ///
    /// ### Using an ObservableTransducer
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: StateInitialising,
        proxy: Proxy? = nil,
        env: Transducer.Env,
        output: sending some Subject<Output>,
        completion: Completion? = nil,
    ) where
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
            proxy: proxy ?? Proxy(),
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        let outputValue = try await Transducer.run(
                            storage: storage,
                            proxy: proxy,
                            env: env,
                            output: output,
                            systemActor: systemActor
                        )
                        result = .success(outputValue)
                    } catch {
                        result = .failure(error)
                    }
                    completion.completed(with: result)
                }
            },
            content: { _, _ in fatalError("No content") }
        )
    }

    /// Initialises a _transducer actor_ that runs an effect transducer with an update function that has the
    /// signature `(inout State, Event) -> (Self.Effect?, Output)`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The intial state.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///
    /// ## Examples
    ///
    /// ### Using an ObservableTransducer
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: StateInitialising,
        proxy: Proxy? = nil,
        env: Transducer.Env,
        completion: Completion? = nil,
    ) where
        Transducer: Oak.EffectTransducer,
        Transducer.TransducerOutput == (Transducer.Effect?, Output)
    {
        self.init(
            of: type,
            initialState: initialState,
            proxy: proxy,
            env: env,
            output: NoCallback(),
            completion: completion
        )
    }

    /// Initialises a _transducer actor_ that runs an effect transducer with an update function that has the
    /// signature `(inout State, Event) -> Self.Effect?`.
    ///
    /// - Note: The Oak library has implementations for a `SwiftUI View` (aka `TransducerView`)
    /// and an `Observable` (aka `ObservableTransducer`) which conform to protocol
    /// `TransducerActor` and thus are _transducer actors_.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer reaches a terminal state, it will be forcibly terminated. If the
    /// transducer reaches a terminal state before the actor will be destroyed, user interactions send to
    /// the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The intial state.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a Result that contains either the successful output value or an error if the transducer failed.
    ///
    /// ## Examples
    ///
    /// ### Using an ObservableTransducer
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: StateInitialising,
        proxy: Proxy? = nil,
        env: Transducer.Env,
        completion: Completion? = nil,
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
            proxy: proxy ?? Proxy(),
            completion: completion,
            runTransducer: { storage, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Void, Error>
                    do {
                        try await Transducer.run(
                            storage: storage,
                            proxy: proxy,
                            env: env,
                            systemActor: systemActor
                        )
                        result = .success(Void())
                    } catch {
                        result = .failure(error)
                    }
                    completion.completed(with: result)
                }
            },
            content: { _, _ in fatalError("No content") }
        )
    }

}
