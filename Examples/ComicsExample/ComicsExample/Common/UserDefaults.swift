import Foundation

@propertyWrapper
struct UserDefault<Value: Codable> {
    let key: String
    let defaultValue: Value
    var container: UserDefaults = .standard

    var wrappedValue: Value {
        get {
            if let data = container.data(forKey: key) {
                return try! JSONDecoder().decode(Value.self, from: data)
            } else {
                return defaultValue
            }
        }
        set {
            let data = try! JSONEncoder().encode(newValue) as NSData
            container.set(data, forKey: key)
        }
    }
}
