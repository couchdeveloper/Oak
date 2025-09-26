# Installation

Add Oak to your Swift package or Xcode project.

## Swift Package Manager

Add Oak as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/couchdeveloper/Oak.git", from: "1.0.0")
]
```

Then add Oak to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["Oak"]
)
```

## Xcode Projects

1. In Xcode, select **File → Add Package Dependencies**
2. Enter the repository URL: `https://github.com/couchdeveloper/Oak.git`
3. Select your version requirements
4. Add Oak to your target

## Platform Requirements

Oak requires:
- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 6.2+
- Xcode 15.0+

## Importing Oak

Import Oak in your Swift files:

```swift
import Oak
```

For SwiftUI integration, Oak is designed to work directly with SwiftUI views without additional imports.