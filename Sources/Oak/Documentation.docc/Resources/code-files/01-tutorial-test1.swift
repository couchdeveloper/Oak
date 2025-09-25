import Testing

@Test func testBasicCounterOperations() {
    var state = SimpleCounter.initialState
    
    // Test increment
    let result1 = SimpleCounter.update(&state, event: .increment)
    #expect(result1 == 1)
    
    // Test another increment  
    let result2 = SimpleCounter.update(&state, event: .increment)
    #expect(result2 == 2)
    
    // Verify state contains the expected count
    if case .idle(let count) = state {
        #expect(count == 2)
    }
}