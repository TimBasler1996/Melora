import SwiftUI

struct ProfileFinishStepView: View {
    
    @ObservedObject var vm: ProfileSetupWizardViewModel
    let onFinished: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            Text("Finish")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Ready to go live. We’ll upload your photos and mark your profile as complete.")
                .font(AppFonts.footnote())
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            
            card {
                VStack(alignment: .leading, spacing: 10) {
                    row("Name", vm.displayName.isEmpty ? "—" : vm.displayName)
                    row("Age", vm.ageString.isEmpty ? "—" : vm.ageString)
                    row("Hometown", vm.hometown.isEmpty ? "—" : vm.hometown)
                    row("Music taste", vm.musicTaste.isEmpty ? "—" : vm.musicTaste)
                    row("Photos selected", "\(vm.selectedImages.compactMap { $0 }.count)/3")
                }
            }
            
            if let error = vm.errorMessage, !error.isEmpty {
                Text(error)
                    .font(AppFonts.footnote())
                    .foregroundColor(.red)
            }
            
            Button {
                Task {
                    await vm.finishOnboarding()
                    if vm.errorMessage == nil || vm.errorMessage?.isEmpty == true {
                        onFinished()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if vm.isSaving {
                        ProgressView().tint(.white)
                    }
                    Text(vm.isSaving ? "Saving…" : "Finish setup")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(vm.canFinish ? Color.white.opacity(0.22) : Color.white.opacity(0.12))
                )
                .foregroundColor(.white)
            }
            .disabled(!vm.canFinish || vm.isSaving)
            .opacity((!vm.canFinish || vm.isSaving) ? 0.6 : 1)
        }
    }
    
    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.mutedText)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(AppFonts.body())
                .foregroundColor(AppColors.primaryText)
            Spacer()
        }
    }
    
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
    }
}

