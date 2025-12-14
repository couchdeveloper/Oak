import Settings
import SwiftUI

extension AppSettingValues {
    static let prefix = "app_"

    @Setting public var score: Int = 0
    @Setting public var onOrOff: Bool = false

}

struct AppSettingsView: View {
    @AppSetting(\.$score) var score
    @AppSetting(\.$onOrOff) var onOrOff

    var body: some View {
        Form {
            TextField("Enter your score", value: $score, format: .number)
                .textFieldStyle(.roundedBorder)
                .padding()
            Toggle("On or Off", isOn: $onOrOff)

            Text("Your score was \(score).")
            
            Text(verbatim: "\(AppSettingValues.store.dictionaryRepresentation())")
        }
    }
}

#if DEBUG
import SettingsMock

#Preview {
    VStack {
        AppSettingsView()
            .environment(\.userDefaultsStore, UserDefaultsStoreMock.standard)
        Text(verbatim: "\(UserDefaultsStoreMock.standard.integer(forKey: "score"))")
    }
}
#endif
