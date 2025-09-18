//
//  Binding.swift
//  Oak
//
//  Created by Andreas Grosam on 08.08.25.
// See also: https://gist.github.com/AliSoftware/ecb5dfeaa7884fc0ce96178dfdd326f8
#if false
// @propertyWrapper
@dynamicMemberLookup
public struct Binding<Value> {

    private let getValue: () -> Value
    private let setValue: (Value) -> Void

    /// Creates a binding with closures that read and write the binding value.
    ///
    /// A binding conforms to Sendable only if its wrapped value type also
    /// conforms to Sendable. It is always safe to pass a sendable binding
    /// between different concurrency domains. However, reading from or writing
    /// to a binding's wrapped value from a different concurrency domain may or
    /// may not be safe, depending on how the binding was created. Oak will
    /// issue a warning at runtime if it detects a binding being used in a way
    /// that may compromise data safety.
    ///
    /// For a "computed" binding created using get and set closure parameters,
    /// the safety of accessing its wrapped value from a different concurrency
    /// domain depends on whether those closure arguments are isolated to
    /// a specific actor. For example, a computed binding with closure arguments
    /// that are known (or inferred) to be isolated to the main actor must only
    /// ever access its wrapped value on the main actor as well, even if the
    /// binding is also sendable.
    ///
    /// - Parameters:
    ///   - get: A closure that retrieves the binding value. The closure has no
    ///     parameters, and returns a value.
    ///   - set: A closure that sets the binding value. The closure has the
    ///     following parameter:
    ///       - newValue: The new value of the binding value.
    public init(
        get: @escaping () -> Value,
        set: @escaping (Value) -> Void
    ) {
        self.setValue = set
        self.getValue = get
    }

    /// The underlying value referenced by the binding variable.
    ///
    /// This property provides primary access to the value's data. However, you
    /// don't access `wrappedValue` directly. Instead, you use the property
    /// variable created with the ``Binding`` attribute.
    ///
    /// When a mutable binding value changes, the new value is immediately
    /// available. However, updates to a view displaying the value happens
    /// asynchronously, so the view may not show the change immediately.
    public var wrappedValue: Value {
        get { self.getValue() }
        nonmutating set { setValue(newValue) }
    }

    /// A projection of the binding value that returns a binding.
    ///
    /// Use the projected value to pass a binding value down a hierarchy.
    /// To get the `projectedValue`, prefix the property variable with `$`.
    public var projectedValue: Binding<Value> { self }

    /// Creates a binding from the value of another binding.
    public init(projectedValue: Binding<Value>) {
        self.setValue = projectedValue.setValue
        self.getValue = projectedValue.getValue
    }

    /// Returns a binding to the resulting value of a given key path.
    ///
    /// - Parameter keyPath: A key path to a specific resulting value.
    ///
    /// - Returns: A new binding.
    public subscript<Subject>(
        dynamicMember keyPath: WritableKeyPath<Value, Subject>
    ) -> Binding<Subject> {
        Binding<Subject>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}

extension Binding {
    func map<Subject>(_ keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> {
        Binding<Subject>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}

/*
@dynamicMemberLookup protocol BindingConvertible {
    associatedtype Value

    var binding: Binding<Self.Value> { get }

    subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Self.Value, Subject>) -> Binding<Subject> { get }
}

extension BindingConvertible {
    public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Self.Value, Subject>) -> Binding<Subject> {
        return Binding(
            get: { self.binding.wrappedValue[keyPath: keyPath] },
            set: { self.binding.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}

//: `XBinding` is one of those types on which we want that `@dynamicMemberLookup` feature:
extension Binding: BindingConvertible {
    var binding: Binding<Value> { self } // well for something already a `Binding`, just use itself!
}
*/

#endif

#if false
extension Binding: Sequence where Value: MutableCollection {

    /// A type representing the sequence's elements.
    public typealias Element = Binding<Value.Element>

    /// A type that provides the sequence's iteration interface and
    /// encapsulates its iteration state.
    public typealias Iterator = IndexingIterator<Binding<Value>>

    /// A collection representing a contiguous subrange of this collection's
    /// elements. The subsequence shares indices with the original collection.
    ///
    /// The default subsequence type for collections that don't define their own
    /// is `Slice`.
    public typealias SubSequence = Slice<Binding<Value>>
}

extension Binding: Collection where Value: MutableCollection {

    /// A type that represents a position in the collection.
    ///
    /// Valid indices consist of the position of every element and a
    /// "past the end" position that's not valid for use as a subscript
    /// argument.
    public typealias Index = Value.Index

    /// A type that represents the indices that are valid for subscripting the
    /// collection, in ascending order.
    public typealias Indices = Value.Indices

    /// The position of the first element in a nonempty collection.
    ///
    /// If the collection is empty, `startIndex` is equal to `endIndex`.
    public var startIndex: Binding<Value>.Index {
    }

    /// The collection's "past the end" position---that is, the position one
    /// greater than the last valid subscript argument.
    ///
    /// When you need a range that includes the last element of a collection, use
    /// the half-open range operator (`..<`) with `endIndex`. The `..<` operator
    /// creates a range that doesn't include the upper bound, so it's always
    /// safe to use with `endIndex`. For example:
    ///
    ///     let numbers = [10, 20, 30, 40, 50]
    ///     if let index = numbers.firstIndex(of: 30) {
    ///         print(numbers[index ..< numbers.endIndex])
    ///     }
    ///     // Prints "[30, 40, 50]"
    ///
    /// If the collection is empty, `endIndex` is equal to `startIndex`.
    public var endIndex: Binding<Value>.Index {
    }

    /// The indices that are valid for subscripting the collection, in ascending
    /// order.
    ///
    /// A collection's `indices` property can hold a strong reference to the
    /// collection itself, causing the collection to be nonuniquely referenced.
    /// If you mutate the collection while iterating over its indices, a strong
    /// reference can result in an unexpected copy of the collection. To avoid
    /// the unexpected copy, use the `index(after:)` method starting with
    /// `startIndex` to produce indices instead.
    ///
    ///     var c = MyFancyCollection([10, 20, 30, 40, 50])
    ///     var i = c.startIndex
    ///     while i != c.endIndex {
    ///         c[i] /= 5
    ///         i = c.index(after: i)
    ///     }
    ///     // c == MyFancyCollection([2, 4, 6, 8, 10])
    public var indices: Value.Indices {
    }

    /// Returns the position immediately after the given index.
    ///
    /// The successor of an index must be well defined. For an index `i` into a
    /// collection `c`, calling `c.index(after: i)` returns the same index every
    /// time.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be less than
    ///   `endIndex`.
    /// - Returns: The index value immediately after `i`.
    public func index(after i: Binding<Value>.Index) -> Binding<Value>.Index

    /// Replaces the given index with its successor.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be less than
    ///   `endIndex`.
    public func formIndex(after i: inout Binding<Value>.Index)

    /// Accesses the element at the specified position.
    ///
    /// The following example accesses an element of an array through its
    /// subscript to print its value:
    ///
    ///     var streets = ["Adams", "Bryant", "Channing", "Douglas", "Evarts"]
    ///     print(streets[1])
    ///     // Prints "Bryant"
    ///
    /// You can subscript a collection with any valid index other than the
    /// collection's end index. The end index refers to the position one past
    /// the last element of a collection, so it doesn't correspond with an
    /// element.
    ///
    /// - Parameter position: The position of the element to access. `position`
    ///   must be a valid index of the collection that is not equal to the
    ///   `endIndex` property.
    ///
    /// - Complexity: O(1)
    public subscript(position: Binding<Value>.Index) -> Binding<Value>.Element {
    }
}

extension Binding: BidirectionalCollection
where Value: BidirectionalCollection, Value: MutableCollection {

    /// Returns the position immediately before the given index.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be greater than
    ///   `startIndex`.
    /// - Returns: The index value immediately before `i`.
    public func index(before i: Binding<Value>.Index) -> Binding<Value>.Index

    /// Replaces the given index with its predecessor.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be greater than
    ///   `startIndex`.
    public func formIndex(before i: inout Binding<Value>.Index)
}

extension Binding: RandomAccessCollection
where Value: MutableCollection, Value: RandomAccessCollection {
}
#endif
