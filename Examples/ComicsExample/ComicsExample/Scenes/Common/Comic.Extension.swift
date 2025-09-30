// MARK: - Comic extensions

import Foundation

extension Comics.Comic {

    init(dtoComic: DTO.Comic, isFavourite: Bool) {
        self.id = String(dtoComic.num)
        self.title = dtoComic.title
        self.imageURL = dtoComic.img
        self.altText = dtoComic.alt
        self.isFavourite = isFavourite
        if let date = Comics.Comic.makeDate(day: dtoComic.day, month: dtoComic.month, year: dtoComic.year) {
            self.dateString = Comics.Comic.dateFormatter.string(from: date)
        } else {
            self.dateString = "release unknown"
        }
    }

    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none
        return dateFormatter
    }()

    static func makeDate(day: String, month: String, year: String) -> Date? {
        guard let year = Int(year), let month = Int(month), let day = Int(day) else {
            return nil
        }

        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.timeZone = TimeZone(abbreviation: "PST") // Pacific Standard Time (North America)

        let userCalendar = Calendar(identifier: .gregorian)
        return userCalendar.date(from: dateComponents)
    }

}
