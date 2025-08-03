#if canImport(SwiftUI)
import SwiftUI

/// A SwiftUI view that conforms to `TransducerActor`, enabling any view
/// to act as a transducer actor with its `@State` properties as the FSM state.
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
/// object, such as a "ViewModel".
@MainActor
public struct TransducerView<Transducer, Content>: View, @MainActor TransducerActor
where Transducer: BaseTransducer, Content: View {
    public typealias State = Transducer.State
    public typealias Event = Transducer.Event
    public typealias Output = Transducer.Output
    public typealias Proxy = Transducer.Proxy
    public typealias Input = Transducer.Proxy.Input
    public typealias Storage = Binding<State>

    public struct Completion: @MainActor Oak.Completable {
        public typealias Value = Output
        public typealias Failure = Error

        let f: (Result<Value, Failure>) -> Void

        public init() {
            f = { _ in }
        }
        public init(_ onCompletion: @escaping (Result<Value, Failure>) -> Void) {
            f = onCompletion
        }
        public func completed(with result: Result<Value, Failure>) {
            f(result)
        }
    }

    @SwiftUI.State private var state: State
    @SwiftUI.State private var taskHolder: TaskHolder?

    public let proxy: Proxy

    private let completion: Completion
    private let content: (State, Input) -> Content
    private let runTransducerClosure:
        (
            Storage,
            Proxy,
            Completion,
            isolated any Actor
        ) -> Task<Void, Never>

    /// Do not use this initialiser. This is a required initializer from TransducerActor protocol.
    ///
    /// This is the only method we need to implement. All convenience initializers come from
    /// protocol extensions.
    ///
    /// > Warning: Do not call this initialiser directly. It's called internally by the other initialiser
    /// overloads.
    ///
    /// - Parameters:
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a `Result` that contains either the successful output value or
    ///   an error if the transducer failed.
    ///   - runTransducer: A closure which will be immediately called when the actor will be initialised.
    ///   It starts the transducer which runs in a Swift Task.
    ///   - content: A closure which takes the current state and the input as parameters and
    ///  returns a content. The content closure can be used to drive other components that
    ///  provide an interface and controls.
    ///
    public init(
        initialState: State,
        proxy: Proxy,
        completion: Completion?,
        runTransducer: @escaping (
            Binding<State>,
            Proxy,
            Completion, isolated any Actor
        ) -> Task<Void, Never>,
        content: @escaping (State, Input) -> Content
    ) {
        self._state = SwiftUI.State(wrappedValue: initialState)
        self.proxy = proxy
        self.completion = completion ?? Completion()
        self.runTransducerClosure = runTransducer
        self.content = content
    }

    public var body: some View {
        content(state, proxy.input)
            .onAppear {
                if taskHolder == nil {
                    // TODO: in the completion, reset the taskHolder
                    let transducerTask = runTransducerClosure(
                        $state, proxy, completion, MainActor.shared)
                    self.taskHolder = TaskHolder(transducerTask)
                    Task {
                        _ = await transducerTask.value
                        self.taskHolder = nil
                    }
                }
            }
    }

    public func cancel() {
        proxy.cancel()
        taskHolder?.task.cancel()
    }
}

extension TransducerView {
    final class TaskHolder {
        init(_ task: Task<Void, Never>) {
            self.task = task
        }
        let task: Task<Void, Never>
        deinit {
            task.cancel()
        }
    }
}

// MARK: - Shared TransducerActor Protocol Extensions
//
// Both ObservableTransducer and ActorTransducerView leverage the same protocol extensions:
//
// For Transducer types:
// - init(initialState:proxy:completion:failure:)
// - init(initialState:proxy:output:completion:failure:)
//
// For EffectTransducer types:
// - init(initialState:proxy:env:output:completion:failure:)
// - init(initialState:proxy:env:completion:failure:)
//
// This demonstrates the power of protocol-oriented design - both ObservableTransducer
// and ActorTransducerView share the same initialization logic through protocol extensions.

#if DEBUG

// MARK: - Demo

private enum A: Transducer {
    enum State: NonTerminal {
        init() { self = .start() }
        case start(events: [Event] = [])
        var events: [Event] {
            switch self {
            case .start(let events):
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
    ) {
        switch (event, state) {
        case (.buttonTapped, .start(var events)):
            events.append(event)
            state = .start(events: events)
        }
    }

}

#Preview("Basic TransducerView") {

    TransducerView(of: A.self, initialState: .init()) { state, input in
        Text("TransducerView A")
    }

    TransducerView(
        of: A.self,
        initialState: .init()
    ) { state, input in
        Text("TransducerView B")
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

private enum Counters {}

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
                output: $output,
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

private struct RepeatView: View {

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
                .id(proxy.id)
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

            Text(
                verbatim:
                    "proxy.id: \(self.proxy == nil ? "nil" : "\(self.proxy!.id.uuidString)")"
            )
            .font(.caption)
        }
    }

}

#Preview("Repeat View") {
    RepeatView()
}

private struct RepeatViewInSheet: View {
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
#endif
#endif
