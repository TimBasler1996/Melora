import SwiftUI

struct OnboardingStepBasicsView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private let genderOptions = ["Female", "Male", "Non-binary", "Other"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create your profile")
                .font(AppFonts.title())
                .foregroundColor(AppColors.primaryText)

            Text("A few details so others can recognize you")
                .font(AppFonts.body())
                .foregroundColor(AppColors.secondaryText)

            VStack(spacing: 12) {
                inputField(title: "First name", text: $viewModel.firstName)
                    .textInputAutocapitalization(.words)
                    .keyboardType(.namePhonePad)

                inputField(title: "Last name", text: $viewModel.lastName)
                    .textInputAutocapitalization(.words)
                    .keyboardType(.namePhonePad)

                inputField(title: "City", text: $viewModel.city)
                    .textInputAutocapitalization(.words)
                    .keyboardType(.default)

                birthdayPicker
                genderMenu
            }
        }
    }

    private func inputField(title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(AppFonts.body())
            .foregroundColor(AppColors.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppColors.tintedBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous))
    }

    private var birthdayPicker: some View {
        DatePicker(
            "Birthday",
            selection: $viewModel.birthday,
            in: minimumDate...Date(),
            displayedComponents: .date
        )
        .font(AppFonts.body())
        .foregroundColor(AppColors.primaryText)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColors.tintedBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous))
    }

    private var genderMenu: some View {
        Menu {
            ForEach(genderOptions, id: \.self) { option in
                Button(option) {
                    viewModel.gender = option
                }
            }
        } label: {
            HStack {
                Text(viewModel.gender.isEmpty ? "Gender" : viewModel.gender)
                    .font(AppFonts.body())
                    .foregroundColor(viewModel.gender.isEmpty ? AppColors.secondaryText : AppColors.primaryText)

                Spacer()

                Image(systemName: "chevron.down")
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppColors.tintedBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous))
        }
    }

    private var minimumDate: Date {
        let components = DateComponents(year: 1900, month: 1, day: 1)
        return Calendar.current.date(from: components) ?? Date.distantPast
    }
}

#Preview {
    OnboardingStepBasicsView(viewModel: OnboardingViewModel())
        .padding()
}

