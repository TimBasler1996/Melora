import SwiftUI

struct OnboardingStepBasicsView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private let genderOptions = ["Female", "Male", "Non-binary", "Other"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Create your profile")
                .font(AppFonts.title())
                .foregroundColor(AppColors.primaryText)

            Text("This is how others will see you.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.secondaryText)

            ProfilePreviewHeader(
                firstName: viewModel.firstName,
                city: viewModel.city,
                birthday: viewModel.birthday,
                gender: viewModel.gender
            )

            VStack(spacing: 14) {
                labeledField(title: "First name", isProminent: true) {
                    TextField("First name", text: $viewModel.firstName)
                        .textInputAutocapitalization(.words)
                        .keyboardType(.namePhonePad)
                }

                labeledField(title: "Last name") {
                    TextField("Last name", text: $viewModel.lastName)
                        .textInputAutocapitalization(.words)
                        .keyboardType(.namePhonePad)
                }

                birthdayPicker

                labeledField(title: "City") {
                    TextField("City", text: $viewModel.city)
                        .textInputAutocapitalization(.words)
                        .keyboardType(.default)
                }

                genderSelector
            }
        }
    }

    private func labeledField<Content: View>(
        title: String,
        isProminent: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.mutedText)

            fieldContainer {
                content()
                    .font(isProminent ? .system(size: 18, weight: .semibold, design: .rounded) : AppFonts.body())
                    .foregroundColor(AppColors.primaryText)
                    .disableAutocorrection(true)
            }
        }
    }

    private var birthdayPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Birthday")
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.mutedText)

            fieldContainer {
                HStack(spacing: 12) {
                    DatePicker(
                        "",
                        selection: $viewModel.birthday,
                        in: minimumDate...Date(),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)

                    Spacer(minLength: 0)

                    if let age = viewModel.birthday.age() {
                        Text("\(age)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(AppColors.tintedBackground.opacity(0.6))
                            )
                    }
                }
            }
        }
    }

    private var genderSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gender")
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.mutedText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(genderOptions, id: \.self) { option in
                    Button {
                        viewModel.gender = option
                    } label: {
                        Text(option)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(viewModel.gender == option ? .white : AppColors.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(viewModel.gender == option ? AppColors.primary : AppColors.tintedBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        viewModel.gender == option ? AppColors.primary.opacity(0.8) : Color.white.opacity(0.12),
                                        lineWidth: 1
                                    )
                            )
                    }
                }
            }
        }
    }

    private func fieldContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                    .fill(AppColors.tintedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
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
