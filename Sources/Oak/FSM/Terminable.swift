/// Used to conform Transducer _State_.
///
/// A state is considered terminal if it cannot transition to 
/// any other state.
public protocol Terminable {
    var isTerminal: Bool { get }
}

extension Terminable {
}


public protocol NonTerminal: Terminable {}

extension NonTerminal {
    public var isTerminal: Bool { false }
}
