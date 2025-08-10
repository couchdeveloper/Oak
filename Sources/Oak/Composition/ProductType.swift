
/// A type representing the product type of two values
public struct ProductType<A, B>: ProductTypeProtocol {
    /// The value `a`.
    public var a: A
    
    /// The value `b`.
    public var b: B
    
    /// Creates a new composite environment
    public init(a: A, b: B) {
        self.a = a
        self.b = b
    }
}

public protocol ProductTypeProtocol<A, B> {
    associatedtype A
    associatedtype B
    
    var a: A { get }
    var b: B { get }
}
