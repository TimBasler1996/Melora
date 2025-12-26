import SwiftUI

struct ProfileSetupWizardView: View {
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ProfileSetupWizardViewModel()
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 12) {
                
                header
                
                switch vm.step {
                case .basics:
                    ProfileBasicsStepView(vm: vm)
                case .photos:
                    ProfilePhotosStepView(vm: vm)
                case .finish:
                    ProfileFinishStepView(vm: vm) {
                        dismiss()
                    }
                }
                
                Spacer(minLength: 0)
                
                footerButtons
            }
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .id(vm.seed)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Set up your profile")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Step \(vm.step.rawValue)/3")
                .font(AppFonts.footnote())
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var footerButtons: some View {
        HStack(spacing: 10) {
            Button {
                if vm.step == .basics { dismiss() }
                else { vm.goBack() }
            } label: {
                Text("Back")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.14))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            
            Button {
                switch vm.step {
                case .basics, .photos:
                    vm.goNext()
                case .finish:
                    Task {
                        await vm.finishOnboarding()
                        if vm.errorMessage == nil || vm.errorMessage?.isEmpty == true {
                            dismiss()
                        }
                    }
                }
            } label: {
                Text(vm.step == .finish ? "Finish" : "Continue")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.22))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(nextDisabled)
            .opacity(nextDisabled ? 0.5 : 1)
        }
    }
    
    private var nextDisabled: Bool {
        switch vm.step {
        case .basics: return !vm.canContinueBasics
        case .photos: return !vm.canContinuePhotos
        case .finish: return !vm.canFinish || vm.isSaving
        }
    }
}

