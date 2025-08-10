
/// A type representing a composite event for parallel composition.
///
/// This enum allows either component transducer to receive events independently.
public enum SumTypeEvent<EventA, EventB> {
    /// An event for the first component transducer
    case eventA(EventA)
    
    /// An event for the second component transducer
    case eventB(EventB)
}

