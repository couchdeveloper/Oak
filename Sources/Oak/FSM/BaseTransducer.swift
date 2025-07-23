/// A type that partially defines the interface of a transducer in a finite 
/// state machine. It's the base type for all transducers that can be used
/// in a finite state machine. It defines the types of events, states, outputs,
/// and proxies that the transducer can use. 
public protocol BaseTransducer<Event> {
    
    /// The type of events that the transducer can process, aka the _Input_ of
    /// the FSM.
    associatedtype Event

    /// The type of the _State_ of the FSM.
    ///
    /// This is a type that conforms to the `Terminable` protocol, which means
    /// that it can be in a terminal state. The terminal state is a state in which
    /// the FSM cannot process any more events and cannot produce any more output.
    associatedtype State: Terminable
    
    /// The type of the input interface of the transducer proxy.
    ///
    /// This is used to send events to the transducer.
    typealias Input = Proxy.Input

    /// Part of the _Output_ of the FSM, which includes all non-effects.
    /// 
    /// An output value will be produced by the transducer in every computation
    /// cycle. The transducer can optionally define a `Subject`, which is a
    /// means to let other components observe the output.
    ///
    /// `Output` may be `Void`, which means that the FSM does not
    /// produce an output.
    /// 
    /// > Note: An _EffectTransducer_ always has an `Effect` type as part of its
    ///   `TransducerOutput`. This is a tuple of the form `(Effect?, Output)`
    ///   in cases where `Output`` is not `Void`. Otherwise, the `TransducerOutput`
    ///   is simply `Effect?`.
    /// 
    associatedtype Output = Void

    /// The type of the transducer proxy.
    ///
    /// A proxy is required to execute a transducer to provide the input
    /// interface and to provide an event buffer. It also provides the
    /// ability to terminate the transducer and cases where this should
    /// be necessary.
    ///
    /// The default type for the Proxy is `Proxy<Event>`, which provides
    /// a "fire & forget" style of event sending and also requires an internal
    /// event buffer. Sending may fail if the buffer is full.
    /// 
    /// The other built-in proxy is `AsyncProxy<Event>`, which provides
    /// an async interface for sending events. This interface suspends until
    /// the event has been processed. It does not require an internal event
    /// buffer and sending also cannot fail. This effectively implements
    /// a backpressure mechanism, which prevent a producer to overwhelm the
    /// transducer. The internal processing of the event is usually 
    /// extremely fast, but if a transducer sends output to the subject,
    /// subscribers may block the processing of the event.
    associatedtype Proxy: TransducerProxy<Event> = FSM.Proxy<Event>

    /// This function needs to be defined and return a non-nil Output value 
    /// to ensure correct behaviour of Moore type transducers.
    ///
    /// This function is used to provide an initial output value when the
    /// transducer is initialized with an initial state. For Moore type
    /// transducers, this is necessary to ensure that the transducer can
    /// produce an output value immediately after initialization.
    /// 
    /// The default implementation returns `nil`.    
    static func initialOutput(initialState: State) -> Output?
}


extension BaseTransducer {
    public static func initialOutput(initialState: State) -> Output? {
        return nil
    }
}
