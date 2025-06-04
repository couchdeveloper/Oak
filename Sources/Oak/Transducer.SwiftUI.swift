import SwiftUI

// Regarding @State initialization: see also: https://forums.swift.org/t/why-swiftui-state-property-can-be-initialized-inside-init-this-other-way/62772

/// A SwiftUI View that runs a transducer whose state will be provided by the
/// view itself through a private `@State` variable.
///
/// When the view's body will be executed the very first time it creates a _transducer
/// identity_, i.e. the life-cycle of a transducer. In other words, when the view appears
/// the very first time it starts the transducer. This also associates the proxy given in
/// the view's initialiser to this transducer.
///
/// A transducer view will re-create a transducer identity when it will be mutated with
/// a new proxy. This  also cancells the running transducer (if any).
///
/// A transducer view guarantees that the transducer will be terminated when the
/// view's lifetime ceases.
///
/// > Important: A `TransducerView` _owns_ the state of the transducer. When
/// a Transducer view gets deallocated, it's state will be destoyed and all running
/// tasks will be cancelled. This might not reflect your use case, though! If you
/// absolutely cannot allow a transducer being dependent on the lifetime of a
/// view, use a separate object with an embedded transducer whose lifetime is
/// managed through other means.
///
/// > Tip: A `TransducerView` can be used as a replacement of an observable
/// object and an associated SwiftUI view which holds this object in a `@State`
/// variable.
@MainActor
public struct TransducerView<T: Transducer, Content: View>: View where T.State: Sendable {
    @SwiftUI.State private var task: AutoCancellabelTask? = nil
    @SwiftUI.State private var state: T.State
    let proxy: T.Proxy
    let content: (T.State, @escaping (T.Event) -> Void) -> Content
    let run: @Sendable @isolated(any) (T.Proxy, Binding<T.State>) async throws -> Void
    
    private final class AutoCancellabelTask {
        let task: Task<Void, Error>
        let id: UUID
        init(task: Task<Void, Error>, id: UUID) {
            self.task = task
            self.id = id
        }
        func cancel() {
            task.cancel()
        }
        deinit {
            cancel()
        }
    }
    
    /// Initialises a view, running a transducer which has an update function
    /// with the signature `(inout State, Event) -> Output`.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the view's life-time. If the view will be
    /// desroyed before the transducer will be terminated, it will be forcibly terminated. If the transducer will
    /// be terminated, before the view will be destroyed user interactions send to the transducer will be
    /// ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The start state of the transducer. Default is `init()`.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - out: A type conforming to `Oak.Subject<Output>` where the transducer sends the
    ///   output it produces. The `out` parameter is usually used to notify the parent view, for example
    ///   via a `Binding` which can be directly used for the parameter `out`.
    ///   - initialOutput: An initial value for the output which will be send by the transducer to the
    ///   `out` parameter immediately after the transducer has been started.
    ///   - content: A viewBuilder function that has a parameter providing the current state and a
    ///   closure with which the view can send events ("user intents") to the transducer. The transducer
    ///   view calls this function whenever the state has changed in order to update the content.
    ///
    /// ## Example
    /// Given a transducer, `MyUseCase`, that conforms to `Transducer`, a transducer view can be
    /// created by passing in the _type_ of the transducer and the content view can be created in the
    /// traling closure as shown below:
    ///
    ///```swift
    /// struct ContentView: View {
    ///     var body: some View {
    ///         TransducerView(of: MyUseCase.self) {
    ///             content: { state, send in
    ///                 GreetingView(
    ///                     greeting: state.greeting,
    ///                     send: send
    ///                 )
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    /// The below`GreetingView` view shows how to compose a content view
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
    public init<Output: Sendable, Out: Subject<Output>>(
        of type: T.Type,
        initialState: T.State,
        proxy: T.Proxy? = nil,
        out: Out,
        initialOutput: Output? = nil,
        @ViewBuilder content: @escaping (_ state: T.State, _ send: @escaping (T.Event) -> Void) -> Content
    ) where T.Output == Output, T.Env == Never {
        self.content = content
        self.proxy = proxy ?? Proxy()
        self._state = .init(initialValue: initialState)
        self.run = { @MainActor proxy, binding in
            binding.wrappedValue = initialState
            try await T.run(
                binding: binding,
                proxy: proxy,
                out: out,
                initialOutput: initialOutput
            )
        }
    }

    public init<Output: Sendable, Out: Subject<Output>>(
        of type: T.Type,
        proxy: T.Proxy? = nil,
        out: Out,
        initialOutput: Output? = nil,
        @ViewBuilder content: @escaping (_ state: T.State, _ send: @escaping (T.Event) -> Void) -> Content
    ) where T.Output == Output, T.Env == Never, T.State: DefaultInitializable {
        self.content = content
        self.proxy = proxy ?? Proxy()
        self._state = .init(initialValue: .init())
        self.run = { @MainActor proxy, binding in
            binding.wrappedValue = .init()
            try await T.run(
                binding: binding,
                proxy: proxy,
                out: out,
                initialOutput: initialOutput
            )
        }
    }

    public init(
        of type: T.Type,
        initialState: T.State,
        proxy: T.Proxy? = nil,
        @ViewBuilder content: @escaping (_ state: T.State, _ send: @escaping (T.Event) -> Void) -> Content
    ) where T.Output == Void, T.Env == Never {
        self.content = content
        self.proxy = proxy ?? Proxy()
        self._state = .init(initialValue: initialState)
        self.run = { @MainActor proxy, binding in
            binding.wrappedValue = initialState
            try await T.run(
                binding: binding,
                proxy: proxy,
                out: NoCallbacks()
            )
        }
    }
    
    public init(
        of type: T.Type,
        proxy: T.Proxy? = nil,
        @ViewBuilder content: @escaping (_ state: T.State, _ send: @escaping (T.Event) -> Void) -> Content
    ) where T.Output == Void, T.Env == Never, T.State: DefaultInitializable {
        self.content = content
        self.proxy = proxy ?? Proxy()
        self._state = .init(initialValue: .init())
        self.run = { @MainActor proxy, binding in
            binding.wrappedValue = .init()
            try await T.run(
                binding: binding,
                proxy: proxy,
                out: NoCallbacks()
            )
        }
    }

    public init<Output: Sendable, Out: Subject<Output>>(
        of type: T.Type,
        initialState: T.State,
        proxy: T.Proxy? = nil,
        env: T.Env,
        out: Out,
        initialOutput: Output? = nil,
        @ViewBuilder content: @escaping (_ state: T.State, _ send: @escaping (T.Event) -> Void) -> Content
    ) where T.Output == (Oak.Effect<T.Event, T.Env>?, Output) {
        self.content = content
        self.proxy = proxy ?? Proxy()
        self._state = .init(initialValue: initialState)
        self.run = { @MainActor proxy, binding in
            binding.wrappedValue = initialState
            try await T.run(
                binding: binding,
                proxy: proxy,
                env: env,
                out: out,
                initialOutput: initialOutput
            )
        }
    }
    
    public init<Output: Sendable, Out: Subject<Output>>(
        of type: T.Type,
        proxy: T.Proxy? = nil,
        env: T.Env,
        out: Out,
        initialOutput: Output? = nil,
        @ViewBuilder content: @escaping (_ state: T.State, _ send: @escaping (T.Event) -> Void) -> Content
    ) where T.Output == (Oak.Effect<T.Event, T.Env>?, Output), T.State: DefaultInitializable {
        self.content = content
        self.proxy = proxy ?? Proxy()
        self._state = .init(initialValue: .init())
        self.run = { @MainActor proxy, binding in
            binding.wrappedValue = .init()
            try await T.run(
                binding: binding,
                proxy: proxy,
                env: env,
                out: out,
                initialOutput: initialOutput
            )
        }
    }

    public init(
        of type: T.Type,
        initialState: T.State,
        proxy: T.Proxy? = nil,
        env: T.Env,
        @ViewBuilder content: @escaping (_ state: T.State, _ send: @escaping (T.Event) -> Void) -> Content
    ) where T.Output == Oak.Effect<T.Event, T.Env>? {
        self.content = content
        self.proxy = proxy ?? Proxy()
        self._state = .init(initialValue: initialState)
        self.run = { @MainActor proxy, binding in
            binding.wrappedValue = initialState
            try await T.run(
                binding: binding,
                proxy: proxy,
                env: env
            )
        }
    }

    public init(
        of type: T.Type,
        proxy: T.Proxy? = nil,
        env: T.Env,
        @ViewBuilder content: @escaping (_ state: T.State, _ send: @escaping (T.Event) -> Void) -> Content
    ) where T.Output == Oak.Effect<T.Event, T.Env>?, T.State: DefaultInitializable {
        self.content = content
        self.proxy = proxy ?? Proxy()
        self._state = .init(initialValue: .init())
        self.run = { @MainActor proxy, binding in
            binding.wrappedValue = .init()
            try await T.run(
                binding: binding,
                proxy: proxy,
                env: env
            )
        }
    }

    public var body: some View {
        // #if DEBUG
        // let _ = Self._printChanges()
        // #endif
        content(state, send(_:))
        .task(id: proxy.id) {
            if let autoCancellingTask = self.task, autoCancellingTask.id == proxy.id {
                return
            }
            self.task?.cancel()
            let task = Self.makeTask(proxy: proxy, binding: $state, run: run)
            self.task = AutoCancellabelTask(task: task, id: proxy.id)
        }
    }
    
    static func makeTask(
        proxy: T.Proxy,
        binding: Binding<T.State>,
        run: @escaping @Sendable @isolated(any) (T.Proxy, Binding<T.State>) async throws -> Void
    ) -> Task<Void, Error> {
        return Task { @MainActor in
            do {
                // print("*** Transducer '\(T.self)' (\(proxy.id)) started")
                logger.info("Transducer '\(T.self)' (\(proxy.id)) started")
                try await run(proxy, binding)
                // print("*** Transducer '\(T.self)' terminated with state: \(binding)")
                // logger.info("*** Transducer '\(T.self)' terminated with state: \(binding)")
            } catch {
                // print("*** Transducer '\(T.self)' (\(proxy.id)) terminated due to \(error)")
                logger.warning("Transducer '\(T.self)' (\(proxy.id)) terminated due to \(error)")
            }
        }
    }

    private func send(_ event: T.Event) {
        do {
            try proxy.send(event)
        } catch {
            // TODO: handle error
            logger.warning("Transducer '\(T.self)' (\(proxy.id)) did not handle event \(String(describing: event)) due to \(error)")
        }
    }
}



extension Transducer where Env == Never {
    
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
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. Its usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - output: A type conforming to `Oak.Subject<Output>` where the transducer sends the
    ///   output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the
    ///   transducer when setting its initial state. Note: an initial output value is required when implementing
    ///   a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run(
        isolated: isolated any Actor = #isolation,
        binding: Binding<State>,
        proxy: Proxy,
        out: some Subject<Output>,
        initialOutput: Output? = nil
    ) async throws -> Output {
        try await run(
            storage: binding,
            proxy: proxy,
            out: out,
            initialOutput: initialOutput
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
        isolated: isolated any Actor = #isolation,
        binding: Binding<State>,
        proxy: Proxy
    ) async throws -> Output {
        try await run(
            binding: binding,
            proxy: proxy,
            out: NoCallbacks<Output>()
        )
    }
}


extension Transducer where Env: Sendable {
    
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
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. Its usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    ///   - out: A type conforming to `Oak.Subject<Output>` where the transducer sends the
    ///   output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the
    ///   transducer when setting its initial state. Note: an initial output value is required when implementing
    ///   a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run<Out: Sendable>(
        isolated: isolated any Actor = #isolation,
        binding: Binding<State>,
        proxy: Proxy,
        env: Env,
        out: some Subject<Out>,
        initialOutput: Out? = nil,
    ) async throws -> Out where Output == (Oak.Effect<Event, Env>?, Out) {
        try await run(
            storage: binding,
            proxy: proxy,
            env: env,
            out: out,
            initialOutput: initialOutput
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
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. Its usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    ///   transducer when setting its initial state. Note: an initial output value is required when implementing
    ///   a _Mealy_ automaton.
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    public static func run(
        isolated: isolated any Actor = #isolation,
        binding: Binding<State>,
        proxy: Proxy,
        env: Env,
    ) async throws -> Void where Output == Oak.Effect<Event, Env>? {
        try await run(
            storage: binding,
            proxy: proxy,
            env: env
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
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. Its usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run<Out: Sendable>(
        isolated: isolated any Actor = #isolation,
        binding: Binding<State>,
        proxy: Proxy,
        env: Env
    ) async throws -> Out where Output == (Oak.Effect<Event, Env>?, Out) {
        try await run(
            isolated: isolated,
            binding: binding,
            proxy: proxy,
            env: env,
            out: NoCallbacks<Out>()
        )
    }
}


struct ProxyNotInitializedError: Error {}

extension SwiftUI.Binding: Oak.Storage {
    var value: Value {
        get {
            self.wrappedValue
        }
        nonmutating set {
            self.wrappedValue = newValue
        }
    }
}


#if DEBUG

// MARK: - Demo


fileprivate enum A: Transducer {
    enum State: Terminable, DefaultInitializable {
        init() { self = .start() }
        case start(events: [Event] = [])
        var isTerminal: Bool { false }
        var events: [Event] {
            switch self {
                case .start(events: let events):
                return events
            }
        }
    }
    enum Event {
        case buttonTapped
    }
    
    static func update(
        _ state: inout State,
        event: Event
    ) -> Void {
        switch (event, state) {
        case (.buttonTapped, .start(var events)):
            events.append(event)
            state = .start(events: events)
        }
    }
    
}

#Preview("TransducerView A") {
    TransducerView(of: A.self, initialState: .init()) { state, send in
        VStack {
            Button("+") {
                send(.buttonTapped)
            }
            .buttonStyle(.borderedProminent)
            .padding(32)
            
            let events = state.events.map { "\($0)" }.joined(separator: ", ")
            TextEditor(text: .constant(events))
            .padding()
        }
    }
}


fileprivate enum Counters {}

extension Counters: Transducer {
    
    enum State: Terminable, DefaultInitializable {
        init() { self = .start }
        
        case start
        case counting(counter: Int)
        case terminated(counter: Int)
        
        var isTerminal: Bool { if case .terminated = self { true } else { false } }
        
        var value: Int {
            switch self {
            case .start:
                return 0
            case .counting(counter: let value), .terminated(counter: let value):
                return value
            }
        }
    }
    
    enum Event {
        case intentPlus
        case intentMinus
        case done
    }
    
    typealias Output = Int
        
    static func update(
        _ state: inout State,
        event: Event
    ) -> Int {
        print("*** event: \(event) with current state: \(state)")
        
        switch (event, state) {
        case (.intentPlus, .start):
            state = .counting(counter: 1)
            return state.value

        case (.intentMinus, .start):
            state = .counting(counter: 0)
            return state.value

        case (.done, .start):
            state = .terminated(counter: 0)
            return state.value

        case (.intentPlus, .counting(let counter)) where counter < 10:
            state = .counting(counter: counter + 1)
            return state.value

        case (.intentMinus, .counting(let counter)) where counter > 0:
            state = .counting(counter: counter - 1)
            return state.value

        case (.done, .counting(let counter)):
            state = .terminated(counter: counter)
            return state.value

        case (.intentMinus, .counting):
            return state.value
        case (.intentPlus, .counting):
            return state.value
        case (_, .terminated):
            return state.value
        }
    }
}

extension Counters { enum Views {} }

extension Counters.Views {
    fileprivate struct ComponentView: View {
        @SwiftUI.State private var output: Counters.Output = 0
        var body: some View {
            TransducerView(of: Counters.self, out: $output) { state, send in
                ContentView(
                    state: state,
                    send: send
                )
                .onDisappear {
                    send(.done)
                }
            }
        }
    }

    fileprivate struct ContentView: View {
        let state: Counters.State
        let send: (Counters.Event) -> Void

        var body: some View {
            VStack {
                Text(verbatim: "\(state.value)")
                    .font(.system(size: 62, weight: .bold, design: .default))
                    .padding()
                HStack {
                    Button {
                        send(.intentPlus)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 20, height: 12, alignment: .center)
                            .padding()
                    }
                    .background(Color.mint)
                    .foregroundColor(.white)
                    .font(.title2)
                    .clipShape(Capsule())

                    Button {
                        send(.intentMinus)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 20, height: 12, alignment: .center)
                            .padding()
                    }
                    .background(Color.mint)
                    .foregroundColor(.white)
                    .font(.title2)
                    .clipShape(Capsule())
                }
            }
        }
    }

}

#Preview("Counters ComponentView") {
    Counters.Views.ComponentView()
}


struct RepeatView: View {
    enum T: Transducer {
        enum State: Terminable, DefaultInitializable {
            init() { self = .start }
            case start
            case idle
        }
        enum Event { case start }
        static func update(_ state: inout State, event: Event) {
            print("*** \(event), \(state)")
            switch (event, state) {
            case (.start, .start):
                state = .idle
            case (_, .idle):
                break
            }
            print("*** -> state: \(state)")
        }
    }
    
    
    @State private var proxy: T.Proxy? = nil
    
    var body: some View {
        VStack {
            if let proxy {
                TransducerView(
                    of: T.self,
                    proxy: proxy,
                ) { state, send in
                    let _ = Self._printChanges()
                    Text("\(state)")
                }
                .padding()
                Button("Start again") {
                    self.proxy = T.Proxy(initialEvents: .start)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                Text("proxy.id: \(proxy.id)")
                    .font(.caption)
            } else {
                Text("not initialized")
                .task {
                    proxy = T.Proxy(initialEvents: .start)
                }
            }
        }
    }
}

#Preview("Repeat View") {
    RepeatView()
}

struct RepeatViewInSheet: View {
    @State var isPresented = false
    
    var body: some View {
        Button("Show sheet") {
            self.isPresented.toggle()
        }
        .sheet(isPresented: $isPresented) {
            VStack {
                Text("Swipe down to dismiss the sheet and cancel the transducer.")
                    .padding(32)
                RepeatView()
            }
        }
    }
}

#Preview("RepeatViewInSheet") {
    RepeatViewInSheet()
}


@MainActor
struct FSA<T: Transducer> where T.Output: Sendable {
    let proxy: T.Proxy
    
    init(
        binding: Binding<T.State>,
        initialOutput: T.Output? = nil,
        onOutput: @escaping @Sendable (T.Output) -> Void
    ) where T.Env == Never {
        let proxy = T.Proxy()
        Task {
            try await T.run(
                binding: binding,
                proxy: proxy,
                out: Callback(onOutput),
                initialOutput: initialOutput
            )
        }
        self.proxy = proxy
    }

    init<Output: Sendable>(
        binding: Binding<T.State>,
        initialOutput: Output? = nil,
        env: T.Env,
        onOutput: @escaping @Sendable (Output) -> Void
    ) where T.Env: Sendable, T.Output == (Effect<T.Event, T.Env>?, Output) {
        let proxy = T.Proxy()
        Task {
            try await T.run(
                binding: binding,
                proxy: proxy,
                env: env,
                out: Callback(onOutput),
                initialOutput: initialOutput
            )
        }
        self.proxy = proxy
    }

    func abort() {
        proxy.terminate()
    }
}

#endif
