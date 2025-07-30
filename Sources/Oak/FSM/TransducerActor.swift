
public protocol TransducerActor<State, Proxy> {
    associatedtype State
    associatedtype Proxy: TransducerProxy
    associatedtype Storage: Oak.Storage<State>

    typealias Input = Proxy.Input
    
    var proxy: Proxy { get }
    
    /// Returns a transducer actor.
    ///
    /// > Caution: Do not call this initialiser directly. It's called internally by the other initialiser
    /// overloads.
    ///
    /// - Parameters:
    ///  - isolated: The isolation from the caller.
    ///  - initialState: The start state of the transducer.
    ///  - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///  - runTransducer: A closure which will be immediately called when the actor will be initialised.
    ///   It starts the transducer which runs in a Swift Task.
    ///
    init(
        initialState: State,
        proxy: Proxy,
        runTransducer: (Storage, Proxy, isolated (any Actor)) -> Task<Void, Error>
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
    
    /// Initialises a transducer actor, running a transducer which has an update function
    /// with the signature `(inout State, Event) -> Void`.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer will be terminated, it will be forcibly terminated. If the transducer will
    /// be terminated, before the actor will be destroyed user interactions send to the transducer will be
    /// ignored.
    ///
    /// - Parameters:
    ///  - isolated: The isolation from the caller.
    ///  - type: The type of the transducer.
    ///  - initialState: The start state of the transducer.
    ///  - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///  - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///
    public init<T: Transducer>(
        of type: T.Type = T.self,
        initialState: State,
        proxy: Proxy? = nil,
        completion: (@Sendable (T.Output, isolated (any Actor)) -> Void)? = nil
    ) where T.State == State, T.Proxy == Proxy {
        self.init(
            initialState: initialState,
            proxy: proxy ?? Proxy(),
            runTransducer: { (state: Storage, proxy: Proxy, isolated) in
                // state.value = initialState
                return Task<Void, Error> {
                    _ = isolated
                    let output = try await T.run(
                        storage: state,
                        proxy: proxy,
                        output: NoCallback(),
                        systemActor: isolated
                    )
                    completion?(output, isolated)
                }
            }
        )
    }
    
    /// Initialises a transducer actor, running a transducer which has an update function
    /// with the signature `(inout State, Event) -> Output`.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer will be terminated, it will be forcibly terminated. If the transducer will
    /// be terminated, before the actor will be destroyed user interactions send to the transducer will be
    /// ignored.
    ///
    /// - Parameters:
    ///  - type: The type of the transducer.
    ///  - initialState: The start state of the transducer.
    ///  - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///  - output: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces.
    ///  - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///
    public init<T: Transducer>(
        of type: T.Type = T.self,
        initialState: sending State,
        proxy: Proxy? = nil,
        output: sending some Subject<T.Output>,
        completion: (@Sendable (T.Output, isolated any Actor) -> Void)? = nil,
    ) where T.State == State, T.Proxy == Proxy {
        self.init(
            initialState: initialState,
            proxy: proxy ?? Proxy(),
            runTransducer: { state, proxy, isolated in
                // state.value = initialState
                return Task {
                    _ = isolated
                    let output = try await T.run(
                        storage: state,
                        proxy: proxy,
                        output: output,
                        systemActor: isolated
                    )
                    completion?(output, isolated)
                }
            }
        )
    }

}

extension TransducerActor {
    
    /// Initialises a transducer actor, running a transducer which has an update function
    /// with the signature `(inout State, Event) -> (Self.Effect?, Output)`.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer will be terminated, it will be forcibly terminated. If the transducer will
    /// be terminated, before the actor will be destroyed user interactions send to the transducer will be
    /// ignored.
    ///
    /// - Parameters:
    ///  - type: The type of the transducer.
    ///  - initialState: The start state of the transducer.
    ///  - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///  - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///  - output: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces.
    ///  - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///
    public init<T: EffectTransducer>(
        of type: T.Type = T.self,
        initialState: State,
        proxy: Proxy? = nil,
        env: T.Env,
        output: sending some Subject<T.Output>,
        completion: (@Sendable (T.Output, isolated any Actor) -> Void)? = nil,
    ) where T.State == State, T.Proxy == Proxy, T.TransducerOutput == (T.Effect?, T.Output) {
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
            runTransducer: { state, proxy, isolated in
                // state.value = initialState
                return Task {
                    _ = isolated
                    let output = try await T.run(
                        storage: state,
                        proxy: proxy,
                        env: env,
                        output: output,
                        systemActor: isolated
                    )
                    completion?(output, isolated)
                }
            }
        )
    }

    /// Initialises a transducer actor, running a transducer which has an update function
    /// with the signature `(inout State, Event) -> Self.Effect?`.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the actor's life-time. If the actor will be
    /// desroyed before the transducer will be terminated, it will be forcibly terminated. If the transducer will
    /// be terminated, before the actor will be destroyed user interactions send to the transducer will be
    /// ignored.
    ///
    /// - Parameters:
    ///  - type: The type of the transducer.
    ///  - initialState: The start state of the transducer.
    ///  - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///  - env: An environment value. The environment value will be passed as an argument to an
    ///   `Effect`s' `invoke` function.
    ///  - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///
    public init<T: EffectTransducer>(
        of type: T.Type = T.self,
        initialState: State,
        proxy: Proxy? = nil,
        env: T.Env,
        completion: (@Sendable (isolated any Actor) -> Void)? = nil,
    ) where T.State == State, T.Proxy == Proxy, T.TransducerOutput == T.Effect?, T.Output == Void {
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
            runTransducer: { state, proxy, isolated in
                // state.value = initialState
                return Task {
                    _ = isolated
                    _ = try await T.run(
                        storage: state,
                        proxy: proxy,
                        env: env,
                        systemActor: isolated
                    )
                    completion?(isolated)
                }
            }
        )
    }

}
