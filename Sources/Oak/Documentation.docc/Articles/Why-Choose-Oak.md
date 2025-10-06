# Why Choose Oak?

Oak transforms how teams approach application state management by making reliable, predictable behavior the default rather than an aspiration.

## Beyond Technical Benefits

While Oak provides strong technical advantages like type safety and compile-time guarantees, its real power lies in how it changes the entire development process from design to deployment.

### Alignment with Business Requirements

Oak's state-event model maps naturally to how product teams think about user journeys and acceptance criteria.

#### The Cucumber Connection

Oak's approach mirrors Gherkin/Cucumber scenarios remarkably well:
- **Given** (current state) 
- **When** (event occurs)
- **Then** (new state + effects)

This alignment creates powerful synergies during requirements gathering. Teams using the Gherkin/Cucumber approach already discover that refinement sessions become more productive when framed around state-event scenarios. The whole team naturally thinks through edge cases as they ask "But what if the user is not authenticated when this happens?" These detailed acceptance criteria then provide ideal input for FSM implementation, though the final state machine typically needs more fine-grained states and events than the original acceptance criteria.

#### Collaborative Discovery

The finite state machine model encourages collaborative exploration of requirements:

**Product Owner**: "When a user taps 'Sign In'..."  
**Developer**: "Which state are we in? Logged out, or session expired?"  
**Product Owner**: "Good point - let me add acceptance criteria for both cases."

This conversation naturally leads to complete specifications rather than assumptions.

### Proactive Quality Assurance

Traditional development often treats edge cases as "if we have time" items. Oak makes comprehensive coverage a requirement, not an afterthought.

#### Complete Scenario Coverage

When you define states and events, you must handle every combination. This forces teams to think through scenarios that would otherwise surface as production bugs:

- What happens when a network request times out during user registration?
- How do we handle expired sessions during a purchase flow?
- What if a user receives a push notification while offline?

#### Living Documentation

Your state machine becomes living documentation that stays synchronized with code. Product managers can read the state enums and event definitions to understand exactly how the system behaves.

```swift
enum AuthenticationState {
    case loggedOut
    case authenticating(credentials: Credentials)
    case authenticated(user: User, sessionExpiry: Date)
    case sessionExpired(lastUser: User)
    case locked(until: Date, attempts: Int)
}
```

This enum tells a complete story that anyone can understand.

### Reduced Debugging Time

Teams using Oak report dramatically less time spent debugging state-related issues.

#### Predictable Behavior

Every state transition is deterministic and traceable. When issues occur, you can:
1. Identify the current state
2. Review the event that triggered the transition
3. Verify the logic in the `update` function
4. Reproduce the exact scenario

#### Impossible States Are Impossible

Traditional approaches allow invalid combinations like:
- `isLoggedIn = true` and `currentUser = nil`
- `isLoading = true` and `hasError = true`
- `uploadProgress = 0.8` and `uploadState = "not_started"`

Oak's FSM approach encourages thoughtful state design, leading you to model state as either sum types (enums) or product types (structs) that can only represent valid values, naturally preserving invariants and eliminating invalid state combinations.

### Enhanced Team Velocity

#### Clear Ownership Boundaries

State machines create clear contracts between team members:
- **Product**: Defines states and events (the "what")
- **Engineering**: Implements transitions and effects (the "how")
- **QA**: Verifies every state-event combination

#### Systematic Testing

Testing becomes straightforward when behavior is deterministic:

```swift
func testSuccessfulLogin() {
    var state = AuthState.loggedOut
    let result = Auth.update(&state, event: .loginSucceeded(user))
    
    XCTAssertEqual(state, .authenticated(user: user))
    XCTAssertEqual(result, .storeUserSession(user))
}
```

Every test follows the same pattern: initial state → event → verify new state and effects.

### Business Confidence

#### Guaranteed Completeness

Product managers can have confidence that edge cases are handled because the compiler enforces complete coverage. There are no hidden "assume this works" scenarios.

#### Predictable Releases

Since behavior is explicit and tested, releases become more predictable. The "it works on my machine" problem largely disappears when all possible scenarios are modeled and tested.

#### Easier Feature Evolution

Adding new states or events requires updating all affected transitions, ensuring no scenario is forgotten. The compiler guides the implementation, making feature evolution systematic rather than ad-hoc.

### Onboarding and Knowledge Transfer

#### Self-Documenting Architecture

New team members can understand system behavior by reading state enums and event definitions. The learning curve is gentler because the architecture enforces consistent patterns.

#### Reduced Tribal Knowledge

Traditional codebases often accumulate implicit knowledge about "don't do X when Y is happening." Oak makes these constraints explicit in the type system.

### Long-term Maintainability

#### Consistent Patterns

Every transducer follows the same structure, making the codebase predictable. Developers can quickly understand any part of the system.

#### Refactoring Safety

When business requirements change, the compiler guides necessary updates. You can't accidentally miss updating a state transition because the compiler won't let you.

#### Technical Debt Resistance

Oak's structure naturally resists common sources of technical debt:
- No scattered boolean flags representing state
- No implicit state assumptions
- No missing error handling scenarios

## When Not to Use Oak

Oak's benefits come with learning overhead and structural requirements that may not suit every project:

- **Simple CRUD applications** with minimal state interactions
- **Proof-of-concept projects** where rapid iteration matters more than robustness
- **Teams resistant to structured approaches** who prefer maximum flexibility
- **Legacy integrations** where Oak's patterns conflict with existing architecture

## Getting Started

The best way to experience Oak's benefits is to start with a focused use case:

1. **Choose a complex flow** in your application (authentication, checkout, data synchronization)
2. **Map out the states and events** collaboratively with your team
3. **Implement with Oak** and compare the clarity to previous approaches
4. **Measure the difference** in debugging time, test coverage, and team confidence

Teams that adopt Oak systematically report significant improvements in both code quality and team productivity, making it an investment that pays dividends throughout the project lifecycle.