import SwiftUI

/// Shows a list of active sessions around the user.
/// Uses NearbyViewModel which talks to SessionApiService and LocationService.
struct NearbyView: View {
    
    @EnvironmentObject private var locationService: LocationService
    @StateObject private var viewModel = NearbyViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [AppColors.primary.opacity(0.2), AppColors.secondary.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nearby Broadcasts")
                            .font(AppFonts.sectionTitle())
                            .foregroundColor(AppColors.primaryText)
                        
                        if let loc = locationService.currentLocationPoint {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 11))
                                Text(String(format: "Lat %.3f, Lon %.3f", loc.latitude, loc.longitude))
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        } else {
                            Text("Waiting for your location…")
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    // Content
                    Group {
                        if viewModel.isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Loading broadcasts around you…")
                                    .font(AppFonts.body())
                                    .foregroundColor(AppColors.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if viewModel.sessions.isEmpty {
                            VStack(spacing: 10) {
                                Text("No live broadcasts nearby")
                                    .font(AppFonts.body())
                                    .foregroundColor(AppColors.primaryText)
                                Text("Once people around you start broadcasting, they will show up here.")
                                    .font(AppFonts.footnote())
                                    .foregroundColor(AppColors.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 14) {
                                    ForEach(viewModel.sessions.indices, id: \.self) { index in
                                        SessionRowView(
                                            session: $viewModel.sessions[index],
                                            userLocation: locationService.currentLocationPoint
                                        )
                                        .padding(.horizontal, AppLayout.screenPadding)
                                    }
                                    .padding(.top, 6)
                                    .padding(.bottom, 16)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Nearby")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
        }
        .onAppear {
            locationService.requestAuthorizationIfNeeded()
            viewModel.loadNearbySessions(location: locationService.currentLocationPoint)
        }
        .onChange(of: locationService.currentLocationPoint) { newLocation in
            viewModel.loadNearbySessions(location: newLocation)
        }
    }
}
