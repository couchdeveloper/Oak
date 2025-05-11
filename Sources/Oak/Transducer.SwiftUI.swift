import SwiftUI


// Regarding @State initialization: see also: https://forums.swift.org/t/why-swiftui-state-property-can-be-initialized-inside-init-this-other-way/62772

/// A SwiftUI View that runs a transducer whose state will be provided by the
/// view itself through a private `@State` variable.
///
/// A transducer view guarantees that the transducer will be terminated when the
/// view's lifetime ceases.
///
/// > Warning: A `TransducerView` _owns_ the state of the transducer. When
/// a Transducer view gets deallocated, it's state will be destoyed and all running
/// tasks will be cancelled. This might not reflect your use case, though! If you
/// absolutely cannot allow a transducer being dependent on the lifetime of a
/// view, use a separate object with an embedded transducer whose lifetime is
/// managed through other means.
///
/// > Tip: A `TransducerView` can be used as a replacement of an observable
/// object and an associated SwiftUI view which holds this object in a `@State`
/// variable.
struct TransducerView<T: Transducer, Content: View>: View where T.State: DefaultInitializable, T.State: Sendable {
    let terminateOnDisappear: Bool
    @SwiftUI.State private var state: T.State
    @SwiftUI.State private var proxy: Terminator<T.Event>?
    let content: (T.State, @escaping (T.Event) -> Void) -> Content
    let run: @Sendable @isolated(any) (T.Proxy, Binding<T.State>) async throws -> Void
    
    /// Initialises a view, running a transducer which has an update function
    /// with the signature `(inout State, Event) -> Output`.
    ///
    /// The transducer's life-time is bound to the view's life-time. If the view will be desroyed before
    /// the transducer will be terminated, it will be forcibly terminated. If the transducer will be terminated,
    /// before the view will be destroyed user interactions send to the transducer will be ignored.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The start state of the transducer. Default is `init()`.
    ///   - out: A type conforming to `Oak.Subject<Output>` where the transducer sends the
    ///   output it produces. The `out` parameter is usually used to notify the parent view, for example
    ///   via a `Binding` which can be directly used for the parameter `out`.
    ///   - initialOutput: An initial value for the output which will be send by the transducer to the
    ///   `out` parameter immediately after the transducer has been started.
    ///   - terminateOnDisappear: A boolean value which indicates whether the transducer view
    ///   should terminate the transducer when it disapears, when it is not terminated already. Otherwise,
    ///   the transducer would only enforce termination when it gets deallocated. The default is `true`.
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
    ///         TransducerView(of: MyUseCase.self)(
    ///             content: { state, send in
    ///                 GreetingView(
    ///                     greeting: state.greeting,
    ///                     send: send
    ///                 )
    ///             }
    ///         )
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
        initialState: T.State = .init(),
        out: Out,
        initialOutput: Output? = nil,
        terminateOnDisappear: Bool = true,
        @ViewBuilder content: @escaping (_ state: T.State, _ send: @escaping (T.Event) -> Void) -> Content
    ) where T.Output == Output, T.Env == Never {
        self._state = .init(wrappedValue: initialState)
        self.content = content
        self.run = { @MainActor proxy, binding in
            try await T.run(
                binding: binding,
                proxy: proxy,
                out: out,
                initialOutput: initialOutput
            )
        }
        self.terminateOnDisappear = terminateOnDisappear
    }
    
    public init(
        of type: T.Type,
        initialState: T.State = .init(),
        terminateOnDisappear: Bool = true,
        @ViewBuilder content: @escaping (_ state: T.State, _ send: @escaping (T.Event) -> Void) -> Content
    ) where T.Output == Void, T.Env == Never {
        self._state = .init(wrappedValue: initialState)
        self.content = content
        self.run = { @MainActor proxy, binding in
            try await T.run(
                binding: binding,
                proxy: proxy,
                out: NoCallbacks()
            )
        }
        self.terminateOnDisappear = terminateOnDisappear
    }
    
    public init<Output: Sendable, Out: Subject<Output>>(
        of type: T.Type,
        initialState: T.State = .init(),
        env: T.Env,
        out: Out,
        initialOutput: Output? = nil,
        terminateOnDisappear: Bool = true,
        @ViewBuilder content: @escaping (_ state: T.State, _ send: @escaping (T.Event) -> Void) -> Content
    ) where T.Output == (Oak.Effect<T.Event, T.Env>?, Output) {
        self._state = .init(wrappedValue: initialState)
        self.content = content
        self.run = { @MainActor proxy, binding in
            try await T.run(
                binding: binding,
                proxy: proxy,
                env: env,
                out: out,
                initialOutput: initialOutput
            )
        }
        self.terminateOnDisappear = terminateOnDisappear
    }
    
    public init(
        of type: T.Type,
        initialState: T.State = .init(),
        env: T.Env,
        terminateOnDisappear: Bool = true,
        @ViewBuilder content: @escaping (_ state: T.State, _ send: @escaping (T.Event) -> Void) -> Content
    ) where T.Output == Oak.Effect<T.Event, T.Env>? {
        self._state = .init(wrappedValue: initialState)
        self.content = content
        self.run = { @MainActor proxy, binding in
            try await T.run(
                binding: binding,
                proxy: proxy,
                env: env
            )
        }
        self.terminateOnDisappear = terminateOnDisappear
    }
    
    public var body: some View {
        content(state, send(_:))
        .task {
            if proxy == nil {
                let proxy = T.Proxy()
                self.proxy = Terminator(proxy: proxy)
                runTransducerBoundToLifetime(proxy: proxy, state: $state)
            }
        }
        .onDisappear {
            print("TransducerView '\(T.self)' content view disappeared")
            if let proxy = proxy, !state.isTerminal {
                Task {
                    await Task.yield()
                    if !state.isTerminal && self.terminateOnDisappear {
                        print("WARNING: Transducer '\(T.self)' not in terminal state after its View disappeared and flag `terminateOnDisappear` is true. Forcibly terminating...")
                        proxy.proxy.terminate()
                    }
                }
            }
        }
    }
    
    private func send(_ event: T.Event) {
        do {
            guard let proxy = proxy else {
                throw ProxyNotInitializedError()
            }
            try proxy.proxy.send(event)
        } catch {
            // TODO: handle error
            logger.warning ("Transducer '\(T.self)' did not handle event \(String(describing: event)) due to \(error)")
        }
    }
    
    // Runs the transducer synchronously with the appearance of the view, i.e.
    // its lifetime is bound to the apearance state of the view, which might
    // appear and disappear several times during its lifetime.
    private func runTransducerBoundToAppearance(proxy: T.Proxy, state: Binding<T.State>) async {
        do {
            try await run(proxy, $state)
        } catch {
            print("transducer '\(T.self)' abnormally terminated with: \(error)")
        }
    }
    
    // Runs the transducer asynchronously with the appearance of the view, i.e.
    // its lifetime is bound to the actual liftime of the view, i.e. it is
    // run once and only once bound to the lifetime of the view.
    private func runTransducerBoundToLifetime(proxy: T.Proxy, state: Binding<T.State>) {
        Task {
            print("Transducer '\(T.self)' started")
            do {
                try await run(proxy, state)
                print("Transducer '\(T.self)' terminated with terminal state: \(state.wrappedValue)")
            } catch {
                print("Transducer '\(T.self)' terminated due to \(error)")
            }
        }
    }
}



extension Transducer where Env == Never {
    
    /// Runs a transducer with an observable state whose update function has the signatur
    /// `(inout State, Event) -> Output`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor (a `SwiftUI.View`),
    /// that can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function must at least run once, in order successully execute the transducer.
    /// The initial state must not be a terminal state.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. It's usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - output: A type conforming to `Oak.Subject<Output>` where the transducer sends the
    ///   output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the
    ///   transducer when setting its initial state.Note: an initial output value is required when implementing
    ///   a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller.
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

    /// Runs a transducer with an observable state whose update function has the signatur
    /// `(inout State, Event) -> Output`.
    ///
    /// The update function is isolated by the given Actor (a `SwiftUI.View`),
    /// that can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function must at least run once, in order successully execute the transducer.
    /// The initial state must not be a terminal state.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. It's usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller.
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
    
    /// Runs a transducer with an observable state whose update function has the signatur
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor (a `SwiftUI.View`),
    /// that can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function can be designed to optionally return an _effect_. Effects are invoked by
    /// the transducer which usually run within a Swift Task which is managed by the transuder. The tasks
    /// operation can emit events which will be feed back to the transducer. The managed tasks can
    /// be explicitly cancelled in the update function. When the transducer reaches a terminal state _all_
    /// running tasks will be cancelled.
    ///
    /// The update function must at least run once, in order successully execute the transducer.
    /// The initial state must not be a terminal state.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. It's usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    ///   - out: A type conforming to `Oak.Subject<Output>` where the transducer sends the
    ///   output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the
    ///   transducer when setting its initial state.Note: an initial output value is required when implementing
    ///   a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller.
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
    
    /// Runs a transducer with an observable state whose update function has the signatur
    /// `(inout State, Event) -> Effect?`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor (a `SwiftUI.View`),
    /// that can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function can be designed to optionally return an _effect_. Effects are invoked by
    /// the transducer which usually run within a Swift Task which is managed by the transuder. The tasks
    /// operation can emit events which will be feed back to the transducer. The managed tasks can
    /// be explicitly cancelled in the update function. When the transducer reaches a terminal state _all_
    /// running tasks will be cancelled.
    ///
    /// The update function must at least run once, in order successully execute the transducer.
    /// The initial state must not be a terminal state.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. It's usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    ///   transducer when setting its initial state.Note: an initial output value is required when implementing
    ///   a _Mealy_ automaton.
    /// - Warning: The backing store for the state variable must not be mutated by the caller.
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

    /// Runs a transducer with an observable state whose update function has the signatur
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function is isolated by the given Actor (a `SwiftUI.View`),
    /// that can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function can be designed to optionally return an _effect_. Effects are invoked by
    /// the transducer which usually run within a Swift Task which is managed by the transuder. The tasks
    /// operation can emit events which will be feed back to the transducer. The managed tasks can
    /// be explicitly cancelled in the update function. When the transducer reaches a terminal state _all_
    /// running tasks will be cancelled.
    ///
    /// The update function must at least run once, in order successully execute the transducer.
    /// The initial state must not be a terminal state.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - binding: The underlying backing store for the state. It's usually a `@State` variable in the
    ///   SwiftUI view.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller.
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


final class Terminator<Event: Sendable> {
    struct ViewTerminationError: Error {}
    var proxy: Oak.Proxy<Event>
    init(proxy: Oak.Proxy<Event>) {
        self.proxy = proxy
    }
    deinit {
        if !proxy.isTerminated {
            print("Terminator terminating proxy")
            proxy.terminate(failure: ViewTerminationError())
        }
    }
}


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


// MARK: - Demo

#if DEBUG

fileprivate enum A: Transducer {
    enum State: Terminable, DefaultInitializable {
        init() { self = .start }
        case start
        var isTerminal: Bool { false }
    }
    enum Event {
        case start
    }
    
    static func update(
        _ state: inout State,
        event: Event
    ) -> Void {
        switch event {
        case .start:
            break
        }
    }
    
    @MainActor
    static var view: some View {
        TransducerView(of: A.self) { state, send in
            Text("\(state)")
            Button("+") {
                send(.start)
            }
        }
    }
}

#Preview("TransducerView A") {
    A.view
}



fileprivate enum Counters {}

extension Counters: Transducer {
    
    fileprivate enum State: Terminable, DefaultInitializable {
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
    
    fileprivate enum Event {
        case intentPlus
        case intentMinus
        case done
    }
    
    typealias Output = Int
        
    fileprivate static func update(
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
        @State private var output: Counters.Output = 0
        var body: some View {
            TransducerView(of: Counters.self, out: $output) { state, send in
                ContentView(
                    state: state,
                    send: send
                )
                .onDisappear {
                    print("onDisappear")
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

#Preview {
    Counters.Views.ComponentView()
}

/*
struct MyNavigationView: View {
    
    var body: some View {
        NavigationStack {
            NavigationLink("Counter") {
                Counters.ComponentView()
            }
        }
    }
}

#Preview("Within NavigationStack") {
    
    MyNavigationView()
}
 */


#endif


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


