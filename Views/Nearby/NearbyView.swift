import SwiftUI

/// Shows a list of active sessions around the user.
/// Uses NearbyViewModel which talks to SessionApiService and LocationService.
struct NearbyView: View {

    @EnvironmentObject private var locationService: LocationService
    @StateObject private var viewModel = NearbyViewModel()
    @State private var expandedSessionId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    header

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
                                    sortHeader
                                        .padding(.horizontal, AppLayout.screenPadding)
                                        .padding(.top, 6)

                                    ForEach(viewModel.sessions.indices, id: \.self) { index in
                                        let sessionId = viewModel.sessions[index].id
                                        SessionRowView(
                                            session: $viewModel.sessions[index],
                                            userLocation: locationService.currentLocationPoint,
                                            isExpanded: Binding(
                                                get: { expandedSessionId == sessionId },
                                                set: { newValue in
                                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                        expandedSessionId = newValue ? sessionId : nil
                                                    }
                                                }
                                            )
                                        )
                                        .padding(.horizontal, AppLayout.screenPadding)
                                    }
                                    .padding(.bottom, 16)
                                }
                            }
                        }
                    }
                }
            }
            .melScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Nearby")
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.primaryText)
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nearby Broadcasts")
                .font(AppFonts.sectionTitle())
                .foregroundColor(AppColors.primaryText)

            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.secondaryText)
                Text(placeLine)
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
            }

            Text(broadcastingCountLine)
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    /// Human-readable location — never raw coordinates.
    private var placeLine: String {
        if let label = viewModel.locationLabel { return label }
        if locationService.currentLocationPoint == nil { return "Waiting for your location…" }
        return "Nearby"
    }

    private var broadcastingCountLine: String {
        let count = viewModel.sessions.count
        return "\(count) \(count == 1 ? "person" : "people") broadcasting"
    }

    // MARK: - Sort header

    private var sortHeader: some View {
        HStack {
            Text("Closest to you · Distance")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.mutedText)
                .textCase(.uppercase)
                .kerning(0.5)
            Spacer()
        }
    }
}
