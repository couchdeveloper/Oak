
/// A type representing the Sum type of two values
public enum SumType<A, B> {
    /// Output from the first component transducer
    case a(A)
    
    /// Output from the second component transducer
    case b(B)

    public typealias Tuple = (A, B)
    
    init (a: A) {
        self = .a(a)
    }
    
    init(b: B) {
        self = .b(b)
    }
    
    var a: A? {
        switch self {
        case .a(let a): return a
        case .b: return nil
        }
    }
    
    var b: B? {
        switch self {
        case .a: return nil
        case .b(let b): return b
        }
    }
}
