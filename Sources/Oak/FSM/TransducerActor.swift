/// A protocol that defines an actor-based wrapper for transducers, providing observable state and isolation.
///
/// ## Overview
///
/// A `TransducerActor` provides the state for the transducer and the isolation context in which it runs.
/// While transducer functions can be called directly without an actor (in which case they "strictly encapsulate" 
/// the state), the main purpose of having a `TransducerActor` is to provide _observable_ state that can be 
/// integrated with UI frameworks and reactive systems.
///
/// The protocol is designed to work seamlessly with SwiftUI views and types conforming to the `Observable` 
/// protocol from the Observation framework, enabling reactive updates when the transducer's state changes.
///
/// ## Key Characteristics
///
/// - **Observable State**: Unlike standalone transducers that encapsulate state internally, a `TransducerActor` 
///   exposes state in a way that external observers (like UI components) can react to changes.
/// - **Isolation Context**: Provides the isolation boundary for safe concurrent access to the transducer's state.
/// - **Framework Integration**: Enables integration with SwiftUI and other reactive frameworks through observable patterns.
/// - **Life-cycle Management**: The transducer's lifetime is bound to the actor's lifetime, ensuring proper 
///   resource management and cleanup.
/// - **Task-based Execution**: When using a `TransducerActor`, the transducer runs in its own `Task`, providing 
///   concurrent execution without blocking the actor or UI.
/// - **Weak Reference Pattern**: The transducer does not keep a strong reference to the `TransducerActor` while 
///   running. If the actor deinitializes while the transducer is still running, the transducer will be forcibly 
///   cancelled, preventing memory leaks and ensuring clean resource cleanup.
///
/// ## Provided Implementations
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
///     var body: some View {
///         TransducerView(of: MyUseCase.self, initialState: .initial) { state, input in
///             // UI that automatically updates when state changes
///             Text(state.message)
///             Button("Action") { try input.send(.userAction) }
///         }
///     }
/// }
/// ```
///
/// ### Observable Integration
/// ```swift
/// @Observable
/// final class MyModel: ObservableTransducer<MyUseCase> {
///     init() {
///         super.init(of: MyUseCase.self, initialState: .initial)
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
    ///   - runTransducer: A closure which will be immediately called when the actor will be initialised.
    ///   It starts the transducer which runs in a Swift Task.
    ///   - content: A closure which takes the current state and the input as parameters and
    ///  returns a content. The content closure can be used to drive other components that
    ///  provide an interface and controls.
    ///
    init(
        initialState: State,
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

extension TransducerActor {
    
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
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the
    ///   actor creates one.
    ///   - completion: An optional completion handler which will be called once when the transducer 
    ///   completes, either successfully with the final output value or with a failure error.
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
        initialState: State,
        proxy: Proxy? = nil,
        completion: Completion? = nil,
        content: @escaping (State, Input) -> Content
    ) where Transducer: Oak.Transducer, Output == Void {
        self.init(
            initialState: initialState,
            proxy: proxy ?? Proxy(),
            completion: completion,
            runTransducer: { state, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        _ = try await Transducer.run(
                            storage: state,
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
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the
    ///   actor creates one.
    ///   - output: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces.
    ///   - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///   - failure: A closure which will be called once when the transducer completed
    ///   with a failure returning the failure value of the run function.
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
        initialState: sending State,
        proxy: Proxy? = nil,
        output: sending some Subject<Output>,
        completion: Completion? = nil,
        content: @escaping (State, Input) -> Content
    ) where Transducer: Oak.Transducer {
        self.init(
            initialState: initialState,
            proxy: proxy ?? Proxy(),
            completion: completion,
            runTransducer: { state, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        let outputValue = try await Transducer.run(
                            storage: state,
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
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the
    ///   actor creates one.
    ///   - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///   - failure: A closure which will be called once when the transducer completed
    ///   with a failure returning the failure value of the run function.
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
        initialState: sending State,
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

extension TransducerActor {

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
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - output: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces.
    ///   - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///   - failure: A closure which will be called once when the transducer completed
    ///   with a failure returning the failure value of the run function.
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
        initialState: State,
        proxy: Proxy? = nil,
        env: Transducer.Env,
        output: sending some Subject<Output>,
        completion: Completion? = nil,
        content: @escaping (State, Input) -> Content
    ) where Transducer: Oak.EffectTransducer, Transducer.TransducerOutput == (Transducer.Effect?, Output) {
        nonisolated(unsafe) let env = env // TODO: have to silence compiler error: Sending 'env' risks causing data races
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
            runTransducer: { state, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        let outputValue = try await Transducer.run(
                            storage: state,
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
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///   - failure: A closure which will be called once when the transducer completed
    ///   with a failure returning the failure value of the run function.
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
        initialState: State,
        proxy: Proxy? = nil,
        env: Transducer.Env,
        completion: Completion? = nil,
        content: @escaping (State, Input) -> Content
    ) where Transducer: Oak.EffectTransducer, Transducer.TransducerOutput == (Transducer.Effect?, Output) {
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
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///   - failure: A closure which will be called once when the transducer completed
    ///   with a failure returning the failure value of the run function.
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
        initialState: State,
        proxy: Proxy? = nil,
        env: Transducer.Env,
        completion: Completion? = nil,
        content: @escaping (State, Input) -> Content
    ) where Transducer: Oak.EffectTransducer, Transducer.TransducerOutput == Transducer.Effect?, Output == Void {
        nonisolated(unsafe) let env = env // TODO: have to silence compiler error: Sending 'env' risks causing data races
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
            runTransducer: { state, proxy, completion, systemActor in
                return Task {
                    _ = systemActor
                    let result: Result<Transducer.Output, Error>
                    do {
                        _ = try await Transducer.run(
                            storage: state,
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


extension TransducerActor where Content == Never {
    
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
    ///   - isolated: The isolation from the caller.
    ///   - type: The type of the transducer.
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///   - failure: A closure which will be called once when the transducer completed
    ///   with a failure returning the failure value of the run function.
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
            proxy: proxy,
            completion: completion,
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
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - output: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces.
    ///   - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///   - failure: A closure which will be called once when the transducer completed
    ///   with a failure returning the failure value of the run function.
    ///
    /// ## Examples
    ///
    /// ### Using an ObservableTransducer
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: sending State,
        proxy: Proxy? = nil,
        output: sending some Subject<Output>,
        completion: Completion? = nil,
    ) where Transducer: Oak.Transducer {
        self.init(
            initialState: initialState,
            proxy: proxy,
            output: output,
            completion: completion,
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
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///   - failure: A closure which will be called once when the transducer completed
    ///   with a failure returning the failure value of the run function.
    ///
    /// ## Examples
    ///
    /// ### Using an ObservableTransducer
    /// TODO
    ///
    public init(
        of type: Transducer.Type = Transducer.self,
        initialState: sending State,
        proxy: Proxy? = nil,
        completion: Completion? = nil,
    ) where Transducer: Oak.Transducer {
        self.init(
            initialState: initialState,
            proxy: proxy,
            output: NoCallback(),
            completion: completion,
            content: { _, _ in fatalError("No content") }
        )
    }

}

extension TransducerActor where Content == Never {

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
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - output: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces.
    ///   - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///   - failure: A closure which will be called once when the transducer completed
    ///   with a failure returning the failure value of the run function.
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
        env: Transducer.Env,
        output: sending some Subject<Output>,
        completion: Completion? = nil,
    ) where Transducer: Oak.EffectTransducer, Transducer.TransducerOutput == (Transducer.Effect?, Output) {
        self.init(
            initialState: initialState,
            proxy: proxy,
            env: env,
            output: output,
            completion: completion,
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
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///   - failure: A closure which will be called once when the transducer completed
    ///   with a failure returning the failure value of the run function.
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
        env: Transducer.Env,
        completion: Completion? = nil,
    ) where Transducer: Oak.EffectTransducer, Transducer.TransducerOutput == (Transducer.Effect?, Output) {
        self.init(
            initialState: initialState,
            proxy: proxy,
            env: env,
            output: NoCallback(),
            completion: completion,
            content: { _, _ in fatalError("No content") }
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
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///   - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///   - failure: A closure which will be called once when the transducer completed
    ///   with a failure returning the failure value of the run function.
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
        env: Transducer.Env,
        completion: Completion? = nil,
    ) where Transducer: Oak.EffectTransducer, Transducer.TransducerOutput == Transducer.Effect?, Output == Void {
        self.init(
            initialState: initialState,
            proxy: proxy,
            env: env,
            completion: completion,
            content: { _, _ in fatalError("No content") }
        )
    }

}
