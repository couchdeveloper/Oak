#if false
import Testing

// The following code causes a compiler crash when compiled (both iOS and MacOS).
// It's happening with Xcode Version 16.3 (16E140), but was also observed with earlier versions.

// Here we define a function that uses a parameter pack. It takes a pack with arguments and the given other function.
// Inside it's supposed to invoke this function with these arguments, but the compiler crashes even if we do nothing.
// The crash only occurs if I use an optional function as one of the argument types.
// E.g. if I use Int?, it will work fine.
func testParameterPack<each U: Sendable>(_ arg: repeat each U, function: @escaping (repeat each U) async -> Void) {
}

// With this function the code won't compile and cause a crash.
func notWorkingFunction(arg: (@Sendable () -> Void)?) async -> Void {
}

// With this function everything will compile normally.
func workingFunction(arg: Int?) {
}

// func f(_ value: Int) async {}


// Comment out the previous line and uncomment the following line to see it working normally with a function taking an Int?
// testParameterPack(nil, function: workingFunction)
final class Root<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

func foo<A, each T>(
    value: A,
    ts: repeat each T
) {
    let keyPath: ReferenceWritableKeyPath<Root<A>, A> = \.value  // <== Rutime Error
    print("key path: \(keyPath)")
}

func bar<A>(
    value: A
) {
    let keyPath: ReferenceWritableKeyPath<Root<A>, A> = \.value  // <== No runtime errors
    print("key path: \(keyPath)")
}

@Test func test1() async throws {
    testParameterPack(nil, function: notWorkingFunction)
}


// @Test func example() async throws {
//     bar(value: "A") // OK
//     foo(value: "A", ts: 1, 2) // EXC_BAD_ACCESS (code=1, address=0x2)
//     foo(value: "A") // Fatal error: could not demangle keypath type from '�
// }

#endif
