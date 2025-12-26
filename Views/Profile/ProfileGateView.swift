import SwiftUI

/// Entscheidet: Profil-Wizard anzeigen (wenn unvollständig) oder MainView (wenn fertig).
struct ProfileGateView: View {
    
    @StateObject private var vm = ProfileGateViewModel()
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            content
        }
        .onAppear {
            vm.bootstrap()
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            VStack {
                Spacer()
                ProgressView("Loading…")
                    .tint(.white)
                Spacer()
            }
        } else if let error = vm.errorMessage {
            VStack(spacing: 10) {
                Text("Couldn’t start")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(error)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                
                Button("Retry") { vm.bootstrap() }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.18))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, AppLayout.screenPadding)
            
        } else if vm.needsOnboarding {
            // ✅ Wichtig: KEINE Argumente mehr übergeben
            ProfileSetupWizardView()
            
        } else {
            MainView()
        }
    }
}

