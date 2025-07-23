/// Represents the input interface for a transducer in a 
/// finite state machine (FSM).
public protocol AsyncTransducerInput<Event>: Sendable {
    associatedtype Event
    
    /// Sends an event to the transducer.
    /// 
    /// - Parameter event: The event to be sent.
    /// - Throws: An error if the event cannot be delivered, 
    /// for example, the transducer is already terminated, or 
    /// the event buffer is full.
    func send(_ event: Event) async
}


/// Represents the input interface for a transducer in a
/// finite state machine (FSM).
public protocol TransducerInput<Event>: Sendable {
    associatedtype Event
    
    /// Sends an event to the transducer.
    ///
    /// - Parameter event: The event to be sent.
    /// - Throws: An error if the event cannot be delivered,
    /// for example, the transducer is already terminated, or
    /// the event buffer is full.
    func send(_ event: sending Event) throws
}
