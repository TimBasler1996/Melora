import SwiftUI

struct ProfilePreviewHeader: View {
    let firstName: String
    let city: String
    let birthday: Date?
    let gender: String

    var body: some View {
        HStack(spacing: 16) {
            avatarPlaceholder

            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(AppFonts.sectionTitle())
                    .foregroundColor(AppColors.primaryText)

                Text(displayCity)
                    .font(AppFonts.footnote())
                    .foregroundColor(isCityEmpty ? AppColors.mutedText : AppColors.secondaryText)

                if let genderText = genderText {
                    Text(genderText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppColors.primary.opacity(0.12))
                        )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)

            Image(systemName: "person.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }

    private var displayName: String {
        let trimmedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? "Your name" : trimmedName

        if let ageText = ageText, !trimmedName.isEmpty {
            return "\(name), \(ageText)"
        }

        return name
    }

    private var displayCity: String {
        isCityEmpty ? "Add your city" : trimmedCity
    }

    private var trimmedCity: String {
        city.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isCityEmpty: Bool {
        trimmedCity.isEmpty
    }

    private var ageText: String? {
        guard let birthday else { return nil }
        guard let age = birthday.age() else { return nil }
        return "\(age)"
    }

    private var genderText: String? {
        let trimmedGender = gender.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedGender.isEmpty ? nil : trimmedGender
    }
}

#Preview {
    ProfilePreviewHeader(
        firstName: "Sofia",
        city: "Berlin",
        birthday: Calendar.current.date(byAdding: .year, value: -26, to: Date()),
        gender: "Female"
    )
    .padding()
    .background(AppColors.cardBackground)
}
