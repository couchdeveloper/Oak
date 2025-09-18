// TimerMVVMExample.swift
//
// Demonstrates a simple timer effect using pure SwiftUI and MVVM (no Oak).

import Foundation
import SwiftUI

// MARK: - View Model

@MainActor
class TimerMVVMViewModel: ObservableObject {
    @Published private(set) var counter: Int = 0
    @Published private(set) var isRunning: Bool = false

    private var timerTask: Task<Void, Never>? = nil

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    self.counter += 1
                }
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        isRunning = false
    }

    func reset() {
        stop()
        counter = 0
    }

    deinit {
        timerTask?.cancel()
    }
}

// MARK: - View

struct TimerMVVMExample: View {
    @StateObject private var viewModel = TimerMVVMViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Text("Timer MVVM Example")
                .font(.title)
                .padding()

            Text("Counter: \(viewModel.counter)")
                .font(.system(size: 40, weight: .bold))
                .padding()

            Text(viewModel.isRunning ? "Running" : "Stopped")
                .foregroundColor(viewModel.isRunning ? .green : .red)

            HStack(spacing: 20) {
                Button("Start") {
                    viewModel.start()
                }
                .disabled(viewModel.isRunning)
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button("Stop") {
                    viewModel.stop()
                }
                .disabled(!viewModel.isRunning)
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button("Reset") {
                    viewModel.reset()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.opacity(0.05))
    }
}

// MARK: - Preview

#Preview {
    TimerMVVMExample()
}
