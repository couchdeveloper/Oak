import Foundation
import Comics

#if DEBUG
public enum Mocks {}
#endif


#if DEBUG
extension Mocks {
    @MainActor
    public static let favourites: [Comic] = [
        .init(
            id: 1001,
            title: "The Beginning",
            date: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2024, month: 1, day: 15))!,
            imageURL: URL(
                string: "https://example.com/comics/1001.png"
            )!,
            altText: "Protagonist meets a cat"
        ),
        .init(
            id: 1002,
            title: "Plot Twist",
            date: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2024, month: 2, day: 2))!,
            imageURL: URL(
                string: "https://example.com/comics/1002.png"
            )!,
            altText: "A surprising turn of events"
        ),
        .init(
            id: 1003,
            title: "Cliffhanger",
            date: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2024, month: 3, day: 10))!,
            imageURL: URL(
                string: "https://example.com/comics/1003.png"
            )!,
            altText: "Hanging on the edge"
        )
    ]
}

#endif
