import Foundation
import API
import Comics

public enum ComicsServices { }

extension ComicsServices {
    public static func loadComic(id: Int) async throws(Comics.ComicsError) -> Comics.Comic {
        do {
            let dto = try await ComicAPI.comic(with: id)
            return Comics.Comic(dtoComic: dto, isFavourite: false)
        } catch ComicAPI.Error.notFound(let missingId) {
            throw ComicsError.notFound(id: missingId)
        } catch {
            throw ComicsError.other(error)
        }
    }

    public static func loadActualComic() async throws(Comics.ComicsError) -> Comics.Comic {
        do {
            let dto = try await ComicAPI.actualComic()
            return Comics.Comic(dtoComic: dto, isFavourite: false)
        } catch ComicAPI.Error.notFound(let missingId) {
            throw ComicsError.notFound(id: missingId)
        } catch {
            throw ComicsError.other(error)
        }
    }
}

extension Comics.Comic {

    init(dtoComic: DTO.Comic, isFavourite: Bool) {
        let date = Comics.Comic.makeDate(
            day: dtoComic.day,
            month: dtoComic.month,
            year: dtoComic.year
        )
        
        self.init(
            id: dtoComic.num,
            title: dtoComic.title,
            date: date,
            imageURL: dtoComic.img,
            altText: dtoComic.alt,
            isFavourite: isFavourite
        )
    }

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
