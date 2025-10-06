import Testing

@Test func testDecrementEdgeCase() {
    var state = SimpleCounter.initialState
    
    // Test decrement from zero - should stay at zero
    let result = SimpleCounter.update(&state, event: .decrement)
    #expect(result == 0)
    
    // Verify state is still zero
    if case .idle(let count) = state {
        #expect(count == 0)
    }
}