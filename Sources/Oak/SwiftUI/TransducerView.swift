#if canImport(SwiftUI)
import SwiftUI

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
public struct TransducerView<State, Proxy: TransducerProxy, Content: View>: View {
    
    @SwiftUI.State private var state: State
    @SwiftUI.State private var isInitial = true

    let proxy: Proxy
    let proxyCancellable: Proxy.AutoCancellation
    let content: (State, Proxy.Input) -> Content
    let runTransducer: @MainActor (Binding<State>, Proxy) -> Void
    
    private init(
        initialState: State,
        proxy: Proxy,
        content: @escaping (State, Proxy.Input ) -> Content,
        runTransducer: @MainActor @escaping (Binding<State>, Proxy) -> Void
    ) {
        self._state = .init(wrappedValue: initialState)
        self.proxy = proxy
        self.proxyCancellable = proxy.autoCancellation
        self.content = content
        self.runTransducer = runTransducer
    }
    
    /// Initialises a view, running a transducer which has an update function
    /// with the signature `(inout State, Event) -> Void`.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the view's life-time. If the view will be
    /// desroyed before the transducer will be terminated, it will be forcibly terminated. If the transducer will
    /// be terminated, before the view will be destroyed user interactions send to the transducer will be
    /// ignored.
    ///
    /// The closure parameter `send(_:)` of the viewBuilder function can fail when the event
    /// could not successfully enqueued. Usually, this happens only in rare situations.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The start state of the transducer. Default is `init()`.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///   - content: A viewBuilder function that has a parameter providing the current state and a
    ///   closure with which the view can send events ("user intents") to the transducer. The transducer
    ///   view calls the `content` viewBuilder function whenever the state has changed so that the
    ///   content view can update.
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
    ///
    /// > Tip: When the proxy value changes, the view will re-run the transducer with the given
    /// initial value.
    public init<T: Transducer>(
        of type: T.Type = T.self,
        initialState: State,
        proxy: Proxy? = nil,
        completion: ((T.Output) -> Void)? = nil,
        @ViewBuilder content: @MainActor @escaping (
            State,
            Proxy.Input
        ) -> Content
    ) where T.State == State, T.Proxy == Proxy {
        self.init(
            initialState: initialState,
            proxy: proxy ?? Proxy(),
            content: content,
            runTransducer: { (state: Binding<State>, proxy: Proxy) in
                state.wrappedValue = initialState
                _ = Task {
                    do {
                        let output = try await T.run(binding: state, proxy: proxy)
                        completion?(output)
                    } catch {
                        logger.error("Transducer (\(proxy.id) failed: \(error)")
                    }
                }
            }
        )
    }

    /// Initialises a view, running a transducer which has an update function
    /// with the signature `(inout State, Event) -> Output`.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the view's life-time. If the view will be
    /// desroyed before the transducer will be terminated, it will be forcibly terminated. If the transducer will
    /// be terminated, before the view will be destroyed user interactions send to the transducer will be
    /// ignored.
    ///
    /// The closure parameter `send(_:)` of the viewBuilder function can fail when the event
    /// could not successfully enqueued. Usually, this happens only in rare situations.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The start state of the transducer. Default is `init()`.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - out: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces. The `out` parameter is usually used to notify the parent view, for example
    ///   via a `Binding` which can be directly used for the parameter `out`.
    ///   - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///   - content: A viewBuilder function that has a parameter providing the current state and a
    ///   closure with which the view can send events ("user intents") to the transducer. The transducer
    ///   view calls the `content` viewBuilder function whenever the state has changed so that the
    ///   content view can update.
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
    ///
    /// > Tip: When the proxy value changes, the view will re-run the transducer with the given
    /// initial value.
    public init<T: Transducer>(
        of type: T.Type = T.self,
        initialState: State,
        proxy: Proxy? = nil,
        output: some Subject<T.Output>,
        completion: ((T.Output) -> Void)? = nil,
        @ViewBuilder content: @MainActor @escaping (
            State,
            Proxy.Input
        ) -> Content
    ) where T.State == State, T.Proxy == Proxy {
        self.init(
            initialState: initialState,
            proxy: proxy ?? Proxy(),
            content: content,
            runTransducer: { state, proxy in
                state.wrappedValue = initialState
                _ = Task {
                    do {
                        let output = try await T.run(
                            binding: state,
                            proxy: proxy,
                            output: output,
                        )
                        completion?(output)
                    } catch {
                        logger.error("Transducer (\(proxy.id) failed: \(error)")
                    }
                }
            }
        )
    }

    /// Initialises a view, running a transducer which has an update function
    /// with the signature `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the view's life-time. If the view will be
    /// desroyed before the transducer will be terminated, it will be forcibly terminated. If the transducer will
    /// be terminated, before the view will be destroyed user interactions send to the transducer will be
    /// ignored.
    ///
    /// The closure parameter `send(_:)` of the viewBuilder function can fail when the event
    /// could not successfully enqueued. Usually, this happens only in rare situations.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The start state of the transducer. Default is `init()`.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    ///   - out: A type conforming to `Subject<Output>` where the transducer sends the
    ///   output it produces. The `out` parameter is usually used to notify the parent view, for example
    ///   via a `Binding` which can be directly used for the parameter `out`.
    ///   - completion: A closure which will be called once when the transducer completed
    ///   successfully returning the success value of the run function.
    ///   - content: A viewBuilder function that has a parameter providing the current state and a
    ///   closure with which the view can send events ("user intents") to the transducer. The transducer
    ///   view calls the `content` viewBuilder function whenever the state has changed so that the
    ///   content view can update.
    ///
    /// Each content view should have a _state_ constant and a `send` function. The state will
    /// change whenever the transducer produces a new state. The send function is used by the
    /// view to send user's intents (aka events) to the transducer.
    ///
    /// Basically, a content view should be _a function of state_, i.e. it itself performs no logic. This
    /// makes sense, since there's the transducer which solely exists to perform this computation.
    /// A view may only manages its own private state when it is invariant of the given logic defined
    /// by the transducer.
    ///
    /// > Tip: When the proxy value changes, the view will re-run the transducer with the given
    /// initial value.
    public init<T: EffectTransducer>(
        of type: T.Type = T.self,
        initialState: State,
        proxy: Proxy? = nil,
        env: T.Env,
        output: some Subject<T.Output>,
        completion: ((T.Output) -> Void)? = nil,
        @ViewBuilder content: @MainActor @escaping (
            State,
            Proxy.Input
        ) -> Content
    ) where T.State == State, T.Proxy == Proxy, T.TransducerOutput == (T.Effect?, T.Output) {
        self.init(
            initialState: initialState,
            proxy: proxy ?? Proxy(),
            content: content,
            runTransducer: { state, proxy in
                state.wrappedValue = initialState
                _ = Task {
                    do {
                        let output = try await T.run(
                            binding: state,
                            proxy: proxy,
                            env: env,
                            output: output
                        )
                        completion?(output)
                    } catch {
                        logger.error("Transducer (\(proxy.id) failed: \(error)")
                    }
                }
            }
        )
    }

    /// Initialises a view, running a transducer which has an update function
    /// with the signature `(inout State, Event) -> Effect?`.
    ///
    /// The transducer's life-time (i.e. its _identity_) is bound to the view's life-time. If the view will be
    /// desroyed before the transducer will be terminated, it will be forcibly terminated. If the transducer will
    /// be terminated, before the view will be destroyed user interactions send to the transducer will be
    /// ignored.
    ///
    /// The closure parameter `send(_:)` of the viewBuilder function can fail when the event
    /// could not successfully enqueued. Usually, this happens only in rare situations.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The start state of the transducer. Default is `init()`.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - env: An environment value. The environment value will be passed as an argument to
    ///   an `Effect`s' `invoke` function.
    ///   - content: A viewBuilder function that has a parameter providing the current state and a
    ///   closure with which the view can send events ("user intents") to the transducer. The transducer
    ///   view calls the `content` viewBuilder function whenever the state has changed so that the
    ///   content view can update.
    ///
    /// Each content view should have a _state_ constant and a `send` function. The state will
    /// change whenever the transducer produces a new state. The send function is used by the
    /// view to send user's intents (aka events) to the transducer.
    ///
    /// Basically, a content view should be _a function of state_, i.e. it itself performs no logic. This
    /// makes sense, since there's the transducer which solely exists to perform this computation.
    /// A view may only manages its own private state when it is invariant of the given logic defined
    /// by the transducer.
    ///
    /// > Tip: When the proxy value changes, the view will re-run the transducer with the given
    /// initial value.
    public init<T: EffectTransducer>(
        of type: T.Type = T.self,
        initialState: State,
        proxy: Proxy? = nil,
        env: T.Env,
        @ViewBuilder content: @MainActor @escaping (
            State,
            Proxy.Input
        ) -> Content
    ) where T.State == State, T.Proxy == Proxy, T.TransducerOutput == T.Effect?, T.Output == Void {
        self.init(
            initialState: initialState,
            proxy: proxy ?? Proxy(),
            content: content,
            runTransducer: { @MainActor state, proxy in
                state.wrappedValue = initialState
                _ = Task {
                    do {
                        _ = try await T.run(
                            binding: state,
                            proxy: proxy,
                            env: env
                        )
                    } catch {
                        logger.error("Transducer (\(proxy.id) failed: \(error)")
                    }
                }
            }
        )
    }

    public var body: some View {
        VStack {
            content(state, proxy.input)
        }
        .onChange(of: proxy, perform: { [proxy] newProxy in
            proxy.cancel()
            runTransducer($state, newProxy)
        })
        .task {
            let proxy = self.proxy
            if isInitial {
                isInitial = false
                runTransducer($state, proxy)
            }
        }
    }
}

#if DEBUG

// MARK: - Demo

fileprivate enum A: Transducer {
    enum State: NonTerminal {
        init() { self = .start() }
        case start(events: [Event] = [])
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
    
    typealias Output = Void
    
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
    
    
    TransducerView(
        of: A.self,
        initialState: .init()
    ) { state, input in
        VStack {
            Button("+") {
                try? input.send(.buttonTapped)
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
    
    enum State: Terminable {
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
    
    static var initialState: State { .start }
        
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
            TransducerView(
                of: Counters.self,
                initialState: Counters.initialState,
                proxy: Counters.Proxy(),
                output: $output
            ) { state, input in
                ContentView(
                    state: state,
                    send: { event in
                        try? input.send(event)
                    }
                )
                .onDisappear {
                    try? input.send(.done)
                }
            }
        }
    }

    fileprivate struct ContentView: View {
        let state: Counters.State
        let send: (sending Counters.Event) throws -> Void

        var body: some View {
            VStack {
                Text(verbatim: "\(state.value)")
                    .font(.system(size: 62, weight: .bold, design: .default))
                    .padding()
                HStack {
                    Button {
                        try? send(.intentPlus)
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
                        try? send(.intentMinus)
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

#if true
struct RepeatView: View {
    
    final class Foo {
        init() {
            print("Foo init")
        }
        deinit {
            print("Foo deinit")
        }
    }
    
    enum T: Transducer {
        enum State: NonTerminal {
            init() { self = .start }
            case start
            case idle
        }
        static var initialState: State { .init() }
        enum Event { case start }
        typealias Output = Void
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
            if let proxy = self.proxy {
                TransducerView(
                    of: T.self,
                    initialState: T.initialState,
                    proxy: proxy,
                ) { state, input in
                    let _ = Self._printChanges()
                    Text(verbatim: "\(state)")
                }
                .padding()
            }
            
            Button("Cancel Transducer") {
                proxy?.cancel()
                self.proxy = nil
                // self.proxy = .init(T.Proxy())
            }
            .buttonStyle(.bordered)
            .padding()

            Button("Start") {
                let proxy = T.Proxy()
                self.proxy = proxy
                try? proxy.send(.start)
            }
            .buttonStyle(.borderedProminent)
            .padding()
            
            Text(verbatim: "proxy.id: \(self.proxy == nil ? "nil" : "\(self.proxy!.id.uuidString)")")
            .font(.caption)
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
#endif // RepeatView
#endif // DEBUG
#endif // canImport(SwiftUI)

