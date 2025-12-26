import SwiftUI

struct ProfileBasicsStepView: View {
    
    @ObservedObject var vm: ProfileSetupWizardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            Text("Basics")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("This is what others will see when you broadcast nearby.")
                .font(AppFonts.footnote())
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            
            card {
                VStack(spacing: 14) {
                    
                    labeledField(title: "Display name") {
                        TextField("Your name", text: $vm.displayName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                    }
                    
                    HStack(spacing: 12) {
                        labeledField(title: "Age") {
                            TextField("e.g. 29", text: $vm.ageString)
                                .keyboardType(.numberPad)
                        }
                        .frame(width: 110)
                        
                        Spacer(minLength: 0)
                        
                        labeledField(title: "Hometown") {
                            TextField("e.g. Zürich", text: $vm.hometown)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                        }
                    }
                    
                    labeledField(title: "Music taste") {
                        TextField("Techno, Hip Hop, Indie…", text: $vm.musicTaste)
                            .textInputAutocapitalization(.sentences)
                            .disableAutocorrection(true)
                    }
                }
            }
            
            if let error = vm.errorMessage, !error.isEmpty {
                Text(error)
                    .font(AppFonts.footnote())
                    .foregroundColor(.red)
            }
            
            // Optional: Step-1 speichern (kannst du auch weglassen, wenn du erst am Ende speichern willst)
            Button {
                Task {
                    vm.errorMessage = nil
                    vm.isSaving = true
                    defer { vm.isSaving = false }
                    
                    do {
                        try await vm.saveStep1Basics()
                    } catch {
                        vm.errorMessage = error.localizedDescription
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if vm.isSaving {
                        ProgressView().tint(.white)
                    }
                    Text(vm.isSaving ? "Saving…" : "Save basics")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(vm.canContinueBasics ? Color.white.opacity(0.22) : Color.white.opacity(0.12))
                )
                .foregroundColor(.white)
            }
            .disabled(!vm.canContinueBasics || vm.isSaving)
            .opacity((!vm.canContinueBasics || vm.isSaving) ? 0.6 : 1)
        }
    }
    
    // MARK: - UI Helpers
    
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
    }
    
    private func labeledField<Content: View>(title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.mutedText)
            
            content()
                .font(AppFonts.body())
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.tintedBackground)
                )
        }
    }
}

