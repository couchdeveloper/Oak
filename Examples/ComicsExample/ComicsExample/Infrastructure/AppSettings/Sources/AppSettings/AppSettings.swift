import Observation
import Settings
import SwiftUI

extension AppSettingValues {
    @Setting public var score: Int = 0
}

struct AppSettingsView: View {
    @AppSetting(\.$score) var score

    var body: some View {
        Form {
            TextField("Enter your score", value: $score, format: .number)
                .textFieldStyle(.roundedBorder)
                .padding()

            Text("Your score was \(score).")
        }
    }
}

#Preview {
    AppSettingsView()
}
