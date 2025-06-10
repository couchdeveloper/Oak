import SwiftUI
import Observation
import Combine


/// A property wrapper type that instantiates a finite state transducer whose
/// state is observable.
///
/// Use a state transducer as a local finite state transducer that you store
/// in a view hierarchy. Create a state transducer in an App, Scene, or View
/// by applying the `@StateTransducer` attribute to a property declaration
/// and providing the value for the transducer's start state. Declare state
/// transducers as private to prevent setting them from a memberwise
/// initializer, which amy conflict with the storage management that SwiftUI
/// provides.
///
/// The property wrapper's wrapped value represents the _state_ of the
/// transducer. Additional properties, such as the proxy, the optional
/// output and the `send(:)` function can be accessed using the
/// projected value of the property wrapper.
///
///
/// ## Example
/// Given a Transducer definition `Counters` which conforms to the
/// `Transducer` protocol, you declare a local transducer as shown
/// below:
/// ```swift
/// struct CounterView: View {
///     @StateTransducer(
///         of: Counters.self
///     ) private var counter = .start
///
///     var body: some View {
///         VStack {
///             Text("\(counter.value)")
///                 .padding(10)
///             HStack {
///                 Button("-") {
///                     try? $counter.send(.intentMinus)
///                 }
///                 Button("+") {
///                     try? $counter.send(.intentPlus)
///                 }
///             }
///         }
///     }
/// }
/// ```
/// An instance of the state transducer is created only once during the
/// lifetime of the container that declares the state transducer. For example,
/// SwiftUI doesn't create a new instance if a view's inputs change, but does
/// create a new instance if the identity of a view changes.
///
/// When the state of the transducer changes, SwiftUI updates any view that
/// depends on the state, like the ``Text`` view in the above example,
/// which renders the property `value` of the state value.
///
///
/// ## Initialize start state with external value
///
/// When a state transducer's initial state depends on data that comes from
/// outside its container, you can call the object's initializer
/// explicitly from within its container's initializer. For example,
/// suppose the transducer from the previous example should be
/// initialised using a start state of `counting(counter: 5)` and you want
/// to provide the value for that start state from outside the view. You can do this with
/// a call to the state transducer's initializer inside an explicit initializer
/// that you create for the view:
///
///```swift
/// struct CounterView: View {
///     @StateTransducer<Counters> private var counter: Counters.State
///
///     init(initialState: Counters.State) {
///         // SwiftUI ensures that the following initialization uses the
///         // closure only once during the lifetime of the view, so later
///         // changes to the view's initialState input have no effect.
///         _counter = StateTransducer(wrappedValue: initialState)
///     }
///
///     var body: some View {
///         VStack {
///             Text("state: \(counter)")
///         }
///     }
/// }
///```
///
/// Use caution when doing this. SwiftUI only initializes a state transducer
/// the first time you call its initializer in a given view. This ensures that the
/// object provides stable storage even as the view's inputs change.
/// However, it might result in unexpected behavior or unwanted side effects,
/// namely calling the state initialiaser, if you explicitly initialize the state
/// transducer.
///
///
/// ## Sending events to the transducer
///
/// As shown in the example above events, such as user intents can be
/// send to the transducer using the projected value. For example a
/// corresponding event for a button action can be send as shown below:
///
/// ```swift
/// Button("-") {
///     try? $counter.send(.intentMinus)
/// }
///```
/// The send function will only throw an error if the underlying event buffer
/// overflows, or when the transducer is terminated. Both situations rarely
/// happen, though and in most scenarious rarely an error will occur.
///
/// ## Forcibly terminating the transducer
///
/// Normally, a transducer will be terminating itself when reaching a
/// terminal state. However, in certain conditions it may be required to
/// _forcibly_ terminate a transducer, even though it did not reach a
/// terminal state. This can be achieved using the property `proxy` of
/// the projected value:
///
/// ```swift
/// $counter.proxy.terminate()
///```
///
///
/// ## Handling Output values
///
/// When the transducer is generating output values, they can be observed
/// with the SwiftUI `onReceive(_:perform:)` modifier. The receive
/// modifier requires a Combine Publisher. This publisher is available via the
/// `output` property of the projected value of the state transducer:
///
/// ```swift
/// struct CounterView: View {
///     @StateTransducer(of: Counters.self) private var counter
///
///     var body: some View {
///         VStack {
///             Text("value: \(counter.value)")
///                 .padding(10)
///             HStack {
///                 Button("+") {
///                     try? $counter.send(.intentPlus)
///                 }
///             }
///         }
///         .onReceive($counter.output) { newValue in
///             if newValue == 10 {
///                 try? $counter.send(.done)
///             }
///         }
///     }
/// }
///```
/// Note, that the transducer needs to generate output values. In order to
/// create such a transducer the `update()` function needs to be defined
/// accordingly. Note also that an output value will be generated with every
/// computation cycle.
///
/// Say, the `update` function has been defined as this:
///
/// ```swift
/// typealias Output = Int // ‼️ Always declare `Output`!
/// static func update(
///     _ state: inout State,
///     event: Event
/// ) -> Int
/// {
///    ...
/// }
///```
/// Here, the update function returns an `Int` value as the output.
///
/// > Important: When defining a type which conforms to the protocol
///  `Transducer` and when its update function returns an output,
///  ensure you also declare a `typealias` for `Output` accordingly,
///  for example `typealias Output = Int` as shown above.
///
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@MainActor
@propertyWrapper
public struct StateTransducer<T: Oak.Transducer>: @preconcurrency DynamicProperty where T.State: Sendable {
    @State private var once: OnceFSA<T>
        
    init(wrappedValue thunk: @autoclosure @escaping () -> FSA<T>) {
        self._once = .init(wrappedValue: OnceFSA(thunk: thunk))
    }

    /// Creates a new state transducer with an initial start state.
    /// 
    /// You typically don’t call this initializer directly. Instead, SwiftUI
    /// calls it for you when you declare a property with the `@StateTransducer`
    /// attribute in an ``App``, ``Scene``, or ``View`` and provide an initial
    /// value:
    /// 
    ///     struct MyView: View {
    ///         @StateTransducer private var counter(
    ///             of: Counters.self
    ///         ) = .start
    ///
    ///         // ...
    ///     }
    /// 
    /// SwiftUI creates only one instance of the state transducer for each
    /// container instance that you declare. In the above code, SwiftUI
    /// creates `counter` only the first time it initializes a particular
    /// instance of `MyView`. On the other hand, each instance of `MyView`
    /// creates a distinct instance of the data model. For example, each of
    /// the views in the following ``VStack`` has its own transducer:
    /// 
    ///     var body: some View {
    ///         VStack {
    ///             MyView()
    ///             MyView()
    ///         }
    ///     }
    /// 
    /// ### Initialize using external data
    /// 
    /// If the initial state of a state transducer depends on external data, you can
    /// call this initializer directly. However, use caution when doing this,
    /// because SwiftUI only initializes the object once during the lifetime of
    /// the view --- even if you call the state transducer initializer more than
    /// once --- which might result in unexpected behavior. For more information
    /// and an example, see ``StateTransducer``.
    /// 
    /// - Parameters:
    ///   - initialState: The initial state of the trsansducer. The initials state value should be a valid start state.
    ///   - of: The type of the transducer.
    ///   - proxy: The proxy of the transducer.
    ///   - initialOutput: An optional value of the initial output (required when this is a Moore Automaton).
    public init(
        wrappedValue initialState: T.State,
        of: T.Type = T.self,
        proxy: T.Proxy = T.Proxy(),
        initialOutput: T.Output? = nil
    ) where T.TransducerOutput == T.Output, T.Env == Never, T.Output: Sendable {
        let thunk: () -> FSA<T> = {
            FSA<T>(
                initialState: initialState,
                proxy: proxy,
                initialOutput: initialOutput
            )
        }
        self._once = .init(wrappedValue: OnceFSA(thunk: thunk))
    }
        
    /// Creates a new state transducer with an initial start state whose output can
    /// also have effects.
    ///
    /// You typically don’t call this initializer directly. Instead, SwiftUI
    /// calls it for you when you declare a property with the `@StateTransducer`
    /// attribute in an ``App``, ``Scene``, or ``View`` and provide an initial
    /// value:
    ///
    ///     struct MyView: View {
    ///         @StateTransducer(
    ///             of: Counters.self
    ///         ) private var counter = .start
    ///
    ///         // ...
    ///     }
    ///
    /// SwiftUI creates only one instance of the state transducer for each
    /// container instance that you declare. In the above code, SwiftUI
    /// creates `counter` only the first time it initializes a particular
    /// instance of `MyView`. On the other hand, each instance of `MyView`
    /// creates a distinct instance of the data model. For example, each of
    /// the views in the following ``VStack`` has its own transducer:
    ///
    ///     var body: some View {
    ///         VStack {
    ///             MyView()
    ///             MyView()
    ///         }
    ///     }
    ///
    /// ### Initialize using external data
    ///
    /// If the initial state of a state transducer depends on external data, you can
    /// call this initializer directly. However, use caution when doing this,
    /// because SwiftUI only initializes the object once during the lifetime of
    /// the view --- even if you call the state transducer initializer more than
    /// once --- which might result in unexpected behavior. For more information
    /// and an example, see ``StateTransducer``.
    ///
    /// - Parameters:
    ///   - initialState: The initial state of the trsansducer. The initials state value should be a valid start state.
    ///   - of: The type of the transducer.
    ///   - proxy: The proxy of the transducer.
    ///   - env: The environment value which will be passed as an argument to effects when they will be invoked.
    ///   - initialOutput: An optional value of the initial output (required when this is a Moore Automaton).
    public init(
        wrappedValue initialState: T.State,
        of: T.Type = T.self,
        proxy: T.Proxy = T.Proxy(),
        env: T.Env,
        initialOutput: T.Output? = nil
    ) where T.TransducerOutput == (Oak.Effect<T.Event, T.Env>?, T.Output), T.Output: Sendable {
        let thunk = {
            FSA<T>(
                initialState: initialState,
                proxy: proxy,
                env: env,
                initialOutput: initialOutput
            )
        }
        self._once = .init(wrappedValue: OnceFSA(thunk: thunk))
    }
    
    public func update() {
        once()
    }

    /// The state of the transducer.
    public var wrappedValue: T.State {
        once.state
    }

    /// The output of the transducer as a Publisher.
    public var output: some Publisher<T.Output, Never> {
        once.output
    }
    
    /// The proxy for the transducer.
    public var proxy: T.Proxy {
        once.proxy
    }

    /// Enques the event and returns immediately.
    ///
    /// This resumes the transducer loop awaiting the next event and letting it compute
    /// the new state and a new output value.
    ///
    /// When the event buffer is full or when the transducer is terminated, an
    /// exception will be thrown.
    ///
    /// - Parameter event: The event that is sent to the transducer.
    public func send(_ input: T.Event) throws {
        try once.proxy.send(input)
    }

    /// Returns `self`.
    public var projectedValue: Self {
        return self
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension StateTransducer where T.State: DefaultInitializable {
    
    /// Creates a new state transducer with the initial start value given by the
    /// default init function `init()`.
    ///
    /// You typically don’t call this initializer directly. Instead, SwiftUI
    /// calls it for you when you declare a property with the `@StateTransducer`
    /// attribute in an ``App``, ``Scene``, or ``View`` and provide an initial
    /// value:
    ///
    ///     struct MyView: View {
    ///         @StateTransducer<Counters> private var counter
    ///
    ///         // ...
    ///     }
    ///
    /// SwiftUI creates only one instance of the state transducer for each
    /// container instance that you declare. In the above code, SwiftUI
    /// creates `counter` only the first time it initializes a particular
    /// instance of `MyView`. On the other hand, each instance of `MyView`
    /// creates a distinct instance of the data model. For example, each of
    /// the views in the following ``VStack`` has its own transducer:
    ///
    ///     var body: some View {
    ///         VStack {
    ///             MyView()
    ///             MyView()
    ///         }
    ///     }
    ///
    /// ### Initialize using external data
    ///
    /// If the initial state of a state transducer depends on external data, you can
    /// call this initializer directly. However, use caution when doing this,
    /// because SwiftUI only initializes the object once during the lifetime of
    /// the view --- even if you call the state transducer initializer more than
    /// once --- which might result in unexpected behavior. For more information
    /// and an example, see ``StateTransducer``.
    ///
    /// - Parameters:
    ///   - of: The type of the transducer.
    ///   - proxy: The proxy of the transducer.
    ///   - initialOutput: An optional value of the initial output (required when this is a Moore Automaton).
    public init(
        of: T.Type = T.self,
        proxy: T.Proxy = T.Proxy(),
        initialOutput: T.Output? = nil
    ) where T.TransducerOutput == T.Output, T.Env == Never, T.Output: Sendable {
        self.init(
            wrappedValue: .init(),
            of: of,
            proxy: proxy,
            initialOutput: initialOutput
        )
    }
    
    /// Creates a new state transducer with the initial start state given by the default
    /// init function `init()` and whose output can also have effects.
    ///
    /// You typically don’t call this initializer directly. Instead, SwiftUI
    /// calls it for you when you declare a property with the `@StateTransducer`
    /// attribute in an ``App``, ``Scene``, or ``View`` and provide an initial
    /// value:
    ///
    ///     struct MyView: View {
    ///         @StateTransducer<Counters> private var counter
    ///
    ///         // ...
    ///     }
    ///
    /// SwiftUI creates only one instance of the state transducer for each
    /// container instance that you declare. In the above code, SwiftUI
    /// creates `counter` only the first time it initializes a particular
    /// instance of `MyView`. On the other hand, each instance of `MyView`
    /// creates a distinct instance of the data model. For example, each of
    /// the views in the following ``VStack`` has its own transducer:
    ///
    ///     var body: some View {
    ///         VStack {
    ///             MyView()
    ///             MyView()
    ///         }
    ///     }
    ///
    /// ### Initialize using external data
    ///
    /// If the initial state of a state transducer depends on external data, you can
    /// call this initializer directly. However, use caution when doing this,
    /// because SwiftUI only initializes the object once during the lifetime of
    /// the view --- even if you call the state transducer initializer more than
    /// once --- which might result in unexpected behavior. For more information
    /// and an example, see ``StateTransducer``.
    ///
    /// - Parameters:
    ///   - of: The type of the transducer.
    ///   - proxy: The proxy of the transducer.
    ///   - env: The environment value which will be passed as an argument to effects when they will be invoked.
    ///   - initialOutput: An optional value of the initial output (required when this is a Moore Automaton).
    public init(
        of: T.Type = T.self,
        proxy: T.Proxy = T.Proxy(),
        env: T.Env,
        initialOutput: T.Output? = nil
    ) where T.TransducerOutput == (Oak.Effect<T.Event, T.Env>?, T.Output), T.Output: Sendable  {
        self.init(
            wrappedValue: .init(),
            of: of,
            proxy: proxy,
            env: env,
            initialOutput: initialOutput
        )
    }
    
}

// MARK: - Internal

extension Callback {
    init(binding: Binding<Value?>) {
        fn = { value in
            binding.wrappedValue = value
        }
    }
}

extension Callback {
    @MainActor
    init(subject: some Combine.Subject<Value, Never>) {
        self.fn = { @MainActor value in
            subject.send(value)
        }
    }
}


@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@MainActor
final class OnceFSA<T: Transducer> {
    private var thunk: (() -> FSA<T>)?
    private var fsa: FSA<T>!
    
    init(thunk: @escaping () -> FSA<T>) {
        self.thunk = thunk
    }
    
    var state: T.State {
        fsa.state
    }

    var proxy: T.Proxy {
        fsa.proxy
    }
    var output: some Publisher<T.Output, Never> {
        return fsa.out
    }

    func callAsFunction() {
        if let thunk {
            fsa = thunk()
            self.thunk = nil
        }
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@Observable
@MainActor
final class FSA<T: Oak.Transducer> {
    
    private(set) var state: T.State
    
    @ObservationIgnored
    let proxy: T.Proxy
    @ObservationIgnored
    private var task: Task<Void, Error>!
    @ObservationIgnored
    let out: PassthroughSubject<T.Output, Never> = .init()

    init(
        initialState: T.State,
        proxy: T.Proxy,
        initialOutput: T.Output? = nil
    ) where T.TransducerOutput == T.Output, T.Env == Never {
        self.state = initialState
        self.proxy = proxy
        task = Task {
            let _ = try await T.run(
                state: \.state,
                host: self,
                proxy: proxy,
                out: Callback(subject: out),
                initialOutput: initialOutput
            )
        }
    }
    
    init(
        initialState: T.State,
        proxy: T.Proxy,
        env: T.Env,
        initialOutput: T.Output? = nil
    ) where T.TransducerOutput == (Oak.Effect<T.Event, T.Env>?, T.Output) {
        self.state = initialState
        self.proxy = proxy
        task = Task {
            let _ = try await T.run(
                state: \.state,
                host: self,
                proxy: proxy,
                env: env,
                out: Callback(subject: out),
                initialOutput: initialOutput
            )
        }
    }
    
    var output: some Publisher<T.Output, Never> {
        return out
    }
    
    deinit {
        proxy.terminate()
    }
}


// MARK: - Testing

#if DEBUG

fileprivate enum Counters {}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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
    ) -> Output {
        print("*** event: \(event) with current state: \(state)")
        defer {
            print("-> state: \(state)")
        }
        
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


@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
struct CounterView: View {
    @StateTransducer(of: Counters.self) private var counter
    
    var body: some View {
        VStack {
            Text("state: \(counter)")
            Text("value: \(counter.value)")
                .padding(10)
            HStack {
                Button("-") {
                    try? $counter.send(.intentMinus)
                }
                Button("+") {
                    try? $counter.send(.intentPlus)
                }
            }
        }
        .onReceive($counter.output) { newValue in
            print("output: \(newValue)")
            if newValue == 10 {
                try? $counter.send(.done)
            }
        }
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
struct CounterView2: View {
    @StateTransducer<Counters> private var counter: Counters.State
    
    fileprivate init(initialState: Counters.State) {
        // SwiftUI ensures that the following initialization uses the
        // closure only once during the lifetime of the view, so
        // later changes to the view's name input have no effect.
        _counter = StateTransducer(wrappedValue: initialState)
    }
    var body: some View {
        VStack {
            Text("state: \(counter)")
        }
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
#Preview {
    CounterView()
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
#Preview {
    CounterView2(initialState: .counting(counter: 5))
}

#endif
