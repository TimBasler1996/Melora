import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {

    @Published var stepIndex: Int = 1

    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var city: String = ""
    @Published var birthday: Date = Date()
    @Published var gender: String = ""

    @Published var profilePhotoData: Data?
    @Published var photo2Data: Data?
    @Published var photo3Data: Data?

    var progressText: String {
        "\(stepIndex)/3"
    }

    var progressValue: Double {
        Double(stepIndex) / 3.0
    }

    var canContinue: Bool {
        switch stepIndex {
        case 1:
            return canContinueStep1
        case 2:
            return canContinueStep2
        default:
            return true
        }
    }

    var canContinueStep1: Bool {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGender = gender.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedFirst.count >= 2,
              trimmedLast.count >= 2,
              trimmedCity.count >= 2,
              !trimmedGender.isEmpty else {
            return false
        }

        let today = Calendar.current.startOfDay(for: Date())
        let selectedDay = Calendar.current.startOfDay(for: birthday)

        guard selectedDay <= today else { return false }
        guard birthday >= Self.minimumBirthday else { return false }

        return true
    }

    var canContinueStep2: Bool {
        profilePhotoData != nil && photo2Data != nil && photo3Data != nil
    }

    func goNext() {
        guard stepIndex < 3 else { return }
        if stepIndex == 1, !canContinueStep1 {
            return
        }
        if stepIndex == 2, !canContinueStep2 {
            return
        }
        stepIndex += 1
        print("Onboarding step advanced to \(stepIndex)")
    }

    func goBack() {
        guard stepIndex > 1 else { return }
        stepIndex -= 1
    }

    private static var minimumBirthday: Date {
        let components = DateComponents(year: 1900, month: 1, day: 1)
        return Calendar.current.date(from: components) ?? Date.distantPast
    }
}
