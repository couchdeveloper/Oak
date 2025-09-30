import SwiftUI
import Combine

// MARK: - Traditional ViewModel Approach

@MainActor
class CountdownTimerViewModel: ObservableObject {
    
    // MARK: - Published State
    @Published var currentTime: Int = 10
    @Published var startValue: Int = 10
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var isFinished: Bool = false
    @Published var isReady: Bool = true
    
    // MARK: - Private State
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var canStart: Bool {
        return isReady && !isRunning && !isPaused
    }
    
    var canPause: Bool {
        return isRunning && !isPaused
    }
    
    var canResume: Bool {
        return !isRunning && isPaused
    }
    
    var canCancel: Bool {
        return isRunning || isPaused
    }
    
    var canIncrement: Bool {
        return isReady && !isRunning && !isPaused
    }
    
    var canDecrement: Bool {
        return isReady && !isRunning && !isPaused && startValue > 0
    }
    
    // MARK: - Actions
    
    func incrementStartValue() {
        guard canIncrement else { return }
        startValue += 1
        currentTime = startValue
    }
    
    func decrementStartValue() {
        guard canDecrement else { return }
        startValue = max(0, startValue - 1)
        currentTime = startValue
    }
    
    func start() {
        guard canStart else { return }
        
        isReady = false
        isRunning = true
        isPaused = false
        isFinished = false
        currentTime = startValue
        
        startTimer()
    }
    
    func pause() {
        guard canPause else { return }
        
        isRunning = false
        isPaused = true
        
        stopTimer()
    }
    
    func resume() {
        guard canResume else { return }
        
        isRunning = true
        isPaused = false
        
        startTimer()
    }
    
    func cancel() {
        guard canCancel else { return }
        
        stopTimer()
        reset()
    }
    
    func reset() {
        isRunning = false
        isPaused = false
        isFinished = false
        isReady = true
        currentTime = startValue
    }
    
    // MARK: - Private Methods
    
    private func startTimer() {
        stopTimer() // Ensure no existing timer
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        guard isRunning && !isPaused else { return }
        
        if currentTime > 1 {
            currentTime -= 1
        } else {
            // Timer finished
            currentTime = 0
            isRunning = false
            isPaused = false
            isFinished = true
            stopTimer()
        }
    }
    
    deinit {
        stopTimer()
    }
}

// MARK: - Traditional SwiftUI View

struct TraditionalCountdownTimerView: View {
    @StateObject private var viewModel = CountdownTimerViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Countdown Timer (Traditional)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if viewModel.isReady {
                ReadySection(viewModel: viewModel)
            } else if viewModel.isRunning {
                RunningSection(viewModel: viewModel)
            } else if viewModel.isPaused {
                PausedSection(viewModel: viewModel)
            } else if viewModel.isFinished {
                FinishedSection(viewModel: viewModel)
            }
        }
        .padding()
        .frame(maxWidth: 400)
    }
}

struct ReadySection: View {
    @ObservedObject var viewModel: CountdownTimerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Button("-") {
                    viewModel.decrementStartValue()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canDecrement)
                
                Text("\(viewModel.currentTime)")
                    .font(.system(size: 72, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(minWidth: 120)
                
                Button("+") {
                    viewModel.incrementStartValue()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canIncrement)
            }
            
            Text("Ready to start")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button("Start") {
                viewModel.start()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canStart)
        }
    }
}

struct RunningSection: View {
    @ObservedObject var viewModel: CountdownTimerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("\(viewModel.currentTime)")
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                .foregroundColor(viewModel.currentTime <= 5 ? .red : .primary)
            
            Text("Time remaining")
                .font(.headline)
                .foregroundColor(.secondary)
            
            ProgressView(value: Double(viewModel.startValue - viewModel.currentTime), total: Double(viewModel.startValue))
                .frame(width: 200)
            
            HStack(spacing: 16) {
                Button("Pause") {
                    viewModel.pause()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canPause)
                
                Button("Cancel") {
                    viewModel.cancel()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canCancel)
            }
        }
    }
}

struct PausedSection: View {
    @ObservedObject var viewModel: CountdownTimerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("\(viewModel.currentTime)")
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)
            
            Text("Paused")
                .font(.headline)
                .foregroundColor(.orange)
            
            ProgressView(value: Double(viewModel.startValue - viewModel.currentTime), total: Double(viewModel.startValue))
                .frame(width: 200)
            
            HStack(spacing: 16) {
                Button("Resume") {
                    viewModel.resume()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canResume)
                
                Button("Cancel") {
                    viewModel.cancel()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canCancel)
            }
        }
    }
}

struct FinishedSection: View {
    @ObservedObject var viewModel: CountdownTimerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("0")
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
            
            Text("Time's up!")
                .font(.headline)
                .foregroundColor(.green)
            
            Button("Start New Timer") {
                viewModel.reset()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    TraditionalCountdownTimerView()
        .padding()
}