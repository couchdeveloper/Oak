# Common Patterns for State Machines

Practical patterns and examples for modeling common application scenarios using Oak state machines.

## Loading Data Pattern

A fundamental pattern for handling asynchronous data loading with proper error handling and retry capabilities.

```swift
enum DataLoader: EffectTransducer {
    enum State: NonTerminal {
        case idle
        case loading
        case loaded([DataItem])
        case error(Error, canRetry: Bool)
    }
    
    enum Event {
        case load
        case reload
        case dataReceived([DataItem])
        case loadFailed(Error)
        case retry
        case dismiss
    }
    
    struct Env: Sendable {
        var dataService: @Sendable () async throws -> [DataItem]
        var connectivity: @Sendable () -> Bool
    }
    
    static var initialState: State { .idle }
    
    static func update(_ state: inout State, event: Event) -> Effect? {
        switch (state, event) {
        case (.idle, .load), (.error, .retry):
            state = .loading
            return loadDataEffect()
            
        case (.loaded, .reload):
            state = .loading
            return loadDataEffect()
            
        case (.loading, .dataReceived(let items)):
            state = .loaded(items)
            return nil
            
        case (.loading, .loadFailed(let error)):
            let canRetry = error.isRetryable
            state = .error(error, canRetry: canRetry)
            return nil
            
        case (.error, .dismiss):
            state = .idle
            return nil
            
        default:
            return nil
        }
    }
    
    static func loadDataEffect() -> Effect {
        Effect(id: "loadData") { env, input in
            do {
                let items = try await env.dataService()
                try input.send(.dataReceived(items))
            } catch {
                try input.send(.loadFailed(error))
            }
        }
    }
}

extension Error {
    var isRetryable: Bool {
        // Implement retry logic based on error type
        return true
    }
}
```

## Form Validation Pattern

Managing complex forms with real-time validation and submission states.

```swift
enum UserForm: EffectTransducer {
    struct FormData: Sendable {
        var name: String = ""
        var email: String = ""
        var phone: String = ""
        
        var isValid: Bool {
            !name.isEmpty && email.isValidEmail && phone.isValidPhone
        }
    }
    
    enum ValidationError: Error {
        case invalidEmail
        case invalidPhone
        case nameRequired
    }
    
    enum State: Terminable {
        case editing(FormData, errors: [ValidationError])
        case validating(FormData)
        case submitting(FormData)
        case submitted(result: SubmissionResult)
        case cancelled
        
        var isTerminal: Bool {
            switch self {
            case .submitted, .cancelled: return true
            case .editing, .validating, .submitting: return false
            }
        }
    }
    
    enum Event {
        case updateName(String)
        case updateEmail(String)
        case updatePhone(String)
        case validate
        case submit
        case validationComplete([ValidationError])
        case submissionComplete(SubmissionResult)
        case cancel
    }
    
    struct Env: Sendable {
        var submitForm: @Sendable (FormData) async throws -> SubmissionResult
        var validateForm: @Sendable (FormData) async -> [ValidationError]
    }
    
    static var initialState: State {
        .editing(FormData(), errors: [])
    }
    
    static func update(_ state: inout State, event: Event) -> Effect? {
        switch (state, event) {
        case (.editing(var data, _), .updateName(let name)):
            data.name = name
            state = .editing(data, errors: [])
            return validateEffect(data)
            
        case (.editing(var data, _), .updateEmail(let email)):
            data.email = email
            state = .editing(data, errors: [])
            return validateEffect(data)
            
        case (.editing(var data, _), .updatePhone(let phone)):
            data.phone = phone
            state = .editing(data, errors: [])
            return validateEffect(data)
            
        case (.editing(let data, _), .validationComplete(let errors)):
            state = .editing(data, errors: errors)
            return nil
            
        case (.editing(let data, let errors), .submit):
            guard errors.isEmpty && data.isValid else { return nil }
            state = .submitting(data)
            return submitEffect(data)
            
        case (.submitting, .submissionComplete(let result)):
            state = .submitted(result: result)
            return nil
            
        case (_, .cancel):
            state = .cancelled
            return nil
            
        default:
            return nil
        }
    }
    
    static func validateEffect(_ data: FormData) -> Effect {
        Effect(id: "validate") { env, input in
            let errors = await env.validateForm(data)
            try input.send(.validationComplete(errors))
        }
    }
    
    static func submitEffect(_ data: FormData) -> Effect {
        Effect { env, input in
            do {
                let result = try await env.submitForm(data)
                try input.send(.submissionComplete(result))
            } catch {
                try input.send(.submissionComplete(.failure(error)))
            }
        }
    }
}
```

## Authentication Flow Pattern

Complete authentication workflow with multiple steps and error recovery.

```swift
enum AuthFlow: EffectTransducer {
    enum State: Terminable {
        case unauthenticated
        case enteringCredentials(email: String, password: String)
        case authenticating(email: String, password: String)
        case requiresTwoFactor(token: String, email: String)
        case enteringTwoFactor(token: String, email: String, code: String)
        case verifyingTwoFactor(token: String, email: String, code: String)
        case authenticated(User)
        case authenticationFailed(Error, canRetry: Bool)
        case locked
        
        var isTerminal: Bool {
            switch self {
            case .authenticated, .locked: return true
            default: return false
            }
        }
    }
    
    enum Event {
        case startLogin
        case updateEmail(String)
        case updatePassword(String)
        case login
        case authenticationSucceeded(User)
        case authenticationFailed(Error)
        case twoFactorRequired(token: String)
        case updateTwoFactorCode(String)
        case submitTwoFactor
        case twoFactorVerified(User)
        case twoFactorFailed(Error)
        case retry
        case logout
        case accountLocked
    }
    
    struct Env: Sendable {
        var authenticate: @Sendable (String, String) async throws -> AuthResult
        var verifyTwoFactor: @Sendable (String, String) async throws -> User
        var maxAttempts: Int
    }
    
    enum AuthResult {
        case success(User)
        case requiresTwoFactor(token: String)
    }
    
    static var initialState: State { .unauthenticated }
    
    static func update(_ state: inout State, event: Event) -> Effect? {
        switch (state, event) {
        case (.unauthenticated, .startLogin):
            state = .enteringCredentials(email: "", password: "")
            return nil
            
        case (.enteringCredentials(_, let password), .updateEmail(let email)):
            state = .enteringCredentials(email: email, password: password)
            return nil
            
        case (.enteringCredentials(let email, _), .updatePassword(let password)):
            state = .enteringCredentials(email: email, password: password)
            return nil
            
        case (.enteringCredentials(let email, let password), .login):
            state = .authenticating(email: email, password: password)
            return authenticateEffect(email: email, password: password)
            
        case (.authenticating, .authenticationSucceeded(let user)):
            state = .authenticated(user)
            return nil
            
        case (.authenticating, .twoFactorRequired(let token)):
            state = .requiresTwoFactor(token: token, email: extractEmail(from: state))
            return nil
            
        case (.authenticating, .authenticationFailed(let error)):
            let canRetry = !error.isAccountLocked
            if error.isAccountLocked {
                state = .locked
            } else {
                state = .authenticationFailed(error, canRetry: canRetry)
            }
            return nil
            
        case (.requiresTwoFactor(let token, let email), .updateTwoFactorCode(let code)):
            state = .enteringTwoFactor(token: token, email: email, code: code)
            return nil
            
        case (.enteringTwoFactor(let token, let email, let code), .submitTwoFactor):
            state = .verifyingTwoFactor(token: token, email: email, code: code)
            return verifyTwoFactorEffect(token: token, code: code)
            
        case (.verifyingTwoFactor, .twoFactorVerified(let user)):
            state = .authenticated(user)
            return nil
            
        case (.verifyingTwoFactor, .twoFactorFailed(let error)):
            let token = extractToken(from: state)
            let email = extractEmail(from: state)
            state = .requiresTwoFactor(token: token, email: email)
            return nil
            
        case (.authenticationFailed(_, true), .retry):
            state = .enteringCredentials(email: "", password: "")
            return nil
            
        case (.authenticated, .logout):
            state = .unauthenticated
            return nil
            
        default:
            return nil
        }
    }
    
    static func authenticateEffect(email: String, password: String) -> Effect {
        Effect { env, input in
            do {
                let result = try await env.authenticate(email, password)
                switch result {
                case .success(let user):
                    try input.send(.authenticationSucceeded(user))
                case .requiresTwoFactor(let token):
                    try input.send(.twoFactorRequired(token))
                }
            } catch {
                try input.send(.authenticationFailed(error))
            }
        }
    }
    
    static func verifyTwoFactorEffect(token: String, code: String) -> Effect {
        Effect { env, input in
            do {
                let user = try await env.verifyTwoFactor(token, code)
                try input.send(.twoFactorVerified(user))
            } catch {
                try input.send(.twoFactorFailed(error))
            }
        }
    }
}
```

## Navigation Coordinator Pattern

Managing complex navigation flows with state-driven routing.

```swift
enum AppNavigator: EffectTransducer {
    enum Route: Hashable {
        case home
        case profile(User)
        case settings
        case login
        case detail(Item)
    }
    
    enum State: NonTerminal {
        case navigating(stack: [Route], modal: Route?)
    }
    
    enum Event {
        case navigate(Route)
        case push(Route)
        case pop
        case presentModal(Route)
        case dismissModal
        case reset
    }
    
    static var initialState: State {
        .navigating(stack: [.home], modal: nil)
    }
    
    static func update(_ state: inout State, event: Event) -> Effect? {
        switch (state, event) {
        case (.navigating(_, let modal), .navigate(let route)):
            state = .navigating(stack: [route], modal: modal)
            return nil
            
        case (.navigating(var stack, let modal), .push(let route)):
            stack.append(route)
            state = .navigating(stack: stack, modal: modal)
            return nil
            
        case (.navigating(var stack, let modal), .pop):
            if stack.count > 1 {
                stack.removeLast()
            }
            state = .navigating(stack: stack, modal: modal)
            return nil
            
        case (.navigating(let stack, _), .presentModal(let route)):
            state = .navigating(stack: stack, modal: route)
            return nil
            
        case (.navigating(let stack, _), .dismissModal):
            state = .navigating(stack: stack, modal: nil)
            return nil
            
        case (.navigating, .reset):
            state = .navigating(stack: [.home], modal: nil)
            return nil
            
        default:
            return nil
        }
    }
}
```

## Timer and Polling Pattern

Managing recurring operations with proper cancellation.

```swift
enum PollingService: EffectTransducer {
    enum State: NonTerminal {
        case idle
        case polling(interval: TimeInterval, lastUpdate: Date?)
        case paused(interval: TimeInterval, lastUpdate: Date?)
    }
    
    enum Event {
        case startPolling(interval: TimeInterval)
        case stopPolling
        case pausePolling
        case resumePolling
        case tick
        case dataUpdated(Data)
    }
    
    struct Env: Sendable {
        var fetchData: @Sendable () async throws -> Data
    }
    
    static var initialState: State { .idle }
    
    static func update(_ state: inout State, event: Event) -> Effect? {
        switch (state, event) {
        case (.idle, .startPolling(let interval)):
            state = .polling(interval: interval, lastUpdate: nil)
            return pollingEffect(interval: interval)
            
        case (.polling, .stopPolling), (.paused, .stopPolling):
            state = .idle
            return cancelPollingEffect()
            
        case (.polling(let interval, let lastUpdate), .pausePolling):
            state = .paused(interval: interval, lastUpdate: lastUpdate)
            return cancelPollingEffect()
            
        case (.paused(let interval, let lastUpdate), .resumePolling):
            state = .polling(interval: interval, lastUpdate: lastUpdate)
            return pollingEffect(interval: interval)
            
        case (.polling(let interval, _), .dataUpdated(let data)):
            state = .polling(interval: interval, lastUpdate: Date())
            return nil
            
        case (.polling(let interval, let lastUpdate), .tick):
            state = .polling(interval: interval, lastUpdate: lastUpdate)
            return fetchDataEffect()
            
        default:
            return nil
        }
    }
    
    static func pollingEffect(interval: TimeInterval) -> Effect {
        Effect(id: "polling") { env, input in
            while !Task.isCancelled {
                try input.send(.tick)
                try await Task.sleep(for: .seconds(interval))
            }
        }
    }
    
    static func fetchDataEffect() -> Effect {
        Effect { env, input in
            do {
                let data = try await env.fetchData()
                try input.send(.dataUpdated(data))
            } catch {
                // Handle error appropriately
            }
        }
    }
    
    static func cancelPollingEffect() -> Effect {
        Effect.cancel(id: "polling")
    }
}
```

## Pattern Selection Guidelines

### Use Loading Data Pattern When:
- Fetching data from APIs or databases
- Need clear loading states and error handling
- Want retry capabilities
- Handling network connectivity issues

### Use Form Validation Pattern When:
- Building complex forms with multiple fields
- Need real-time validation feedback
- Want to prevent invalid submissions
- Handling multi-step form workflows

### Use Authentication Flow Pattern When:
- Implementing login/logout functionality
- Supporting multi-factor authentication
- Need account lockout protection
- Want clear authentication state tracking

### Use Navigation Coordinator Pattern When:
- Managing complex navigation hierarchies
- Need programmatic navigation control
- Want to decouple navigation from views
- Supporting modal presentations

### Use Timer/Polling Pattern When:
- Need periodic data updates
- Building real-time features
- Want controllable background operations
- Need proper cleanup on view disappearance

These patterns provide starting points for common scenarios. Adapt them to your specific requirements while maintaining Oak's principles of explicit state modeling and pure transition functions.