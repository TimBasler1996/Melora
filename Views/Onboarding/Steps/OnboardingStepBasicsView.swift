import SwiftUI

struct OnboardingStepBasicsView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private let genderOptions = ["Female", "Male", "Non-binary", "Other"]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Create your profile")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Tell us about yourself")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            VStack(spacing: 16) {
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
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))

            fieldContainer {
                content()
                    .font(isProminent ? .system(size: 18, weight: .semibold, design: .rounded) : .system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .disableAutocorrection(true)
            }
        }
    }

    private var birthdayPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Birthday")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))

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
                    .colorScheme(.dark)

                    Spacer(minLength: 0)

                    if let age = viewModel.birthday.age() {
                        Text("\(age)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                    }
                }
            }
        }
    }

    private var genderSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gender")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(genderOptions, id: \.self) { option in
                    Button {
                        viewModel.gender = option
                    } label: {
                        Text(option)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(viewModel.gender == option ? Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.3) : Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        viewModel.gender == option ? Color(red: 0.2, green: 0.85, blue: 0.4) : Color.white.opacity(0.15),
                                        lineWidth: viewModel.gender == option ? 2 : 1
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
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
