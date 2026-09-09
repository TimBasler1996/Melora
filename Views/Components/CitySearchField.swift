import SwiftUI
import MapKit

// MARK: - City Search Completer

@MainActor
final class CitySearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {

    /// A city-level completion: `display` is what the list shows
    /// ("Berlin, Germany"), `city` is what gets stored ("Berlin").
    struct Suggestion: Identifiable, Hashable {
        let city: String
        let display: String
        var id: String { display }
    }

    @Published var query: String = "" {
        didSet { completer.queryFragment = query }
    }
    @Published var suggestions: [Suggestion] = []
    @Published var isSearching: Bool = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        // Cities only: no streets, districts or points of interest.
        completer.addressFilter = MKAddressFilter(including: .locality)
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.suggestions = results
                .compactMap { result -> Suggestion? in
                    let title = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let subtitle = result.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty else { return nil }
                    // With the locality filter the title is the city itself.
                    let display = subtitle.isEmpty ? title : "\(title), \(subtitle)"
                    return Suggestion(city: title, display: display)
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
            TextField("Which city?", text: $completer.query)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.primaryText)
                .disableAutocorrection(true)
                .focused($isFocused)
                .onChange(of: completer.query) { _, newValue in
                    // Keep the bound value in sync with what the user typed so a
                    // city is saved even when no suggestion is tapped.
                    city = newValue
                }

            if isFocused && !completer.suggestions.isEmpty && completer.query.count >= 2 {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(completer.suggestions) { suggestion in
                        Button {
                            city = suggestion.city
                            completer.query = suggestion.city
                            isFocused = false
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.mutedText)
                                Text(suggestion.display)
                                    .font(AppFonts.body())
                                    .foregroundColor(AppColors.primaryText)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)

                        if suggestion.id != completer.suggestions.last?.id {
                            Divider().background(AppColors.stroke)
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
            TextField("Which city?", text: $completer.query)
                .textInputAutocapitalization(.words)
                .keyboardType(.default)
                .focused($isFocused)
                .onChange(of: completer.query) { _, newValue in
                    city = newValue
                }

            if isFocused && !completer.suggestions.isEmpty && completer.query.count >= 2 {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(completer.suggestions) { suggestion in
                        Button {
                            city = suggestion.city
                            completer.query = suggestion.city
                            isFocused = false
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.primary)
                                Text(suggestion.display)
                                    .font(AppFonts.body())
                                    .foregroundColor(AppColors.primaryText)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)

                        if suggestion.id != completer.suggestions.last?.id {
                            Divider().background(AppColors.stroke)
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
