import Foundation

extension Date {
    func age(in calendar: Calendar = .current, referenceDate: Date = Date()) -> Int? {
        let start = calendar.startOfDay(for: self)
        let end = calendar.startOfDay(for: referenceDate)
        guard start <= end else { return nil }
        return calendar.dateComponents([.year], from: start, to: end).year
    }
}
