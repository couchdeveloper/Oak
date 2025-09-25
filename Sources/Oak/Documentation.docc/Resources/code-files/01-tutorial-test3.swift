import Testing

@Test func testResetFromAnyState() {
    var state = SimpleCounter.initialState
    
    // Increment to some value
    _ = SimpleCounter.update(&state, event: .increment)
    _ = SimpleCounter.update(&state, event: .increment)
    _ = SimpleCounter.update(&state, event: .increment)
    
    // Now reset - should go back to zero
    let result = SimpleCounter.update(&state, event: .reset)
    #expect(result == 0)
    
    // Verify state is reset
    if case .idle(let count) = state {
        #expect(count == 0)
    }
}