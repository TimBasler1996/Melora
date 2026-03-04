import SwiftUI
import MapKit

// MARK: - City Search Completer

@MainActor
final class CitySearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {

    @Published var query: String = "" {
        didSet { completer.queryFragment = query }
    }
    @Published var suggestions: [String] = []
    @Published var isSearching: Bool = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.suggestions = results
                .compactMap { result -> String? in
                    let title = result.title
                    let subtitle = result.subtitle
                    // Filter to city-level results (subtitle typically contains country/region)
                    guard !title.isEmpty else { return nil }
                    if subtitle.isEmpty { return title }
                    return "\(title), \(subtitle)"
                }
                .removingDuplicates()
                .prefix(5)
                .map { $0 }
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
        }
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - City Search Field (Onboarding style - dark)

struct CitySearchFieldOnboarding: View {
    @Binding var city: String
    @StateObject private var completer = CitySearchCompleter()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search city...", text: $completer.query)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .disableAutocorrection(true)
                .focused($isFocused)
                .onChange(of: completer.query) { _, newValue in
                    // Don't clear city while user types a new search
                }

            if isFocused && !completer.suggestions.isEmpty && completer.query.count >= 2 {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(completer.suggestions, id: \.self) { suggestion in
                        Button {
                            city = suggestion
                            completer.query = suggestion
                            isFocused = false
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.4))
                                Text(suggestion)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)

                        if suggestion != completer.suggestions.last {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            completer.query = city
        }
    }
}

// MARK: - City Search Field (Profile Edit style - card)

struct CitySearchFieldEdit: View {
    @Binding var city: String
    @StateObject private var completer = CitySearchCompleter()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search city...", text: $completer.query)
                .textInputAutocapitalization(.words)
                .keyboardType(.default)
                .focused($isFocused)

            if isFocused && !completer.suggestions.isEmpty && completer.query.count >= 2 {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(completer.suggestions, id: \.self) { suggestion in
                        Button {
                            city = suggestion
                            completer.query = suggestion
                            isFocused = false
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.primary)
                                Text(suggestion)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(AppColors.primaryText)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)

                        if suggestion != completer.suggestions.last {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            completer.query = city
        }
    }
}
