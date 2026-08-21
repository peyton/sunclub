import Foundation
import MapKit
import SwiftUI

struct CitySearchView: View {
    private struct SearchResult: Identifiable, Equatable {
        let place: SunclubSelectedUVPlace

        var id: String {
            "\(place.displayName)|\(place.latitude)|\(place.longitude)"
        }
    }

    @Environment(\.dismiss) private var dismiss

    let onSelect: (SunclubSelectedUVPlace) -> Bool

    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            SunLightScreen(contentMaxWidth: SunLayout.ContentWidth.form) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Choose a city")
                            .font(AppTextStyle.largeTitle.font)
                            .foregroundStyle(AppPalette.ink)

                        Text("Sunclub saves only the selected coordinates and city name for WeatherKit UV updates.")
                            .font(AppTextStyle.body.font)
                            .foregroundStyle(AppPalette.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    AppCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("City or postal code", text: $query)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.search)
                                .onSubmit(search)
                                .accessibilityIdentifier("citySearch.query")

                            Button(isSearching ? "Searching…" : "Search Apple Maps") {
                                search()
                            }
                            .buttonStyle(SunPrimaryButtonStyle())
                            .sunGlassPrimaryButton()
                            .disabled(trimmedQuery.isEmpty || isSearching)
                            .accessibilityIdentifier("citySearch.submit")
                        }
                    }

                    if let errorMessage {
                        SunStatusCard(
                            title: "City search unavailable",
                            detail: errorMessage,
                            tint: AppColor.warning.opacity(0.8),
                            symbol: "exclamationmark.triangle.fill"
                        )
                        .accessibilityIdentifier("citySearch.error")
                    }

                    if !results.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Results")
                                .font(AppTextStyle.sectionHeader.font)
                                .foregroundStyle(AppPalette.ink)

                            ForEach(results) { result in
                                Button {
                                    select(result.place)
                                } label: {
                                    HStack(spacing: 12) {
                                        SunProductIcon(
                                            systemName: "mappin.and.ellipse",
                                            tint: AppPalette.pool,
                                            size: 38
                                        )

                                        Text(result.place.displayName)
                                            .font(AppTextStyle.bodyMedium.font)
                                            .foregroundStyle(AppPalette.ink)
                                            .multilineTextAlignment(.leading)

                                        Spacer(minLength: 8)

                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(AppPalette.softInk)
                                            .accessibilityHidden(true)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .sunGlassCard(
                                        cornerRadius: AppRadius.medium,
                                        fillOpacity: 1,
                                        interactive: true,
                                        legacyStroke: .clear,
                                        legacyShadow: nil
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Use \(result.place.displayName)")
                                .accessibilityIdentifier("citySearch.result")
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("citySearch.cancel")
                }
            }
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func search() {
        guard !trimmedQuery.isEmpty, !isSearching else {
            return
        }

        isSearching = true
        errorMessage = nil
        results = []
        let requestedQuery = trimmedQuery

        Task {
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = requestedQuery
                request.resultTypes = .address
                let response = try await MKLocalSearch(request: request).start()
                var seen = Set<String>()
                results = response.mapItems.compactMap { item in
                    let coordinate = item.placemark.coordinate
                    let name = displayName(for: item, fallback: requestedQuery)
                    let key = "\(name.lowercased())|\(coordinate.latitude.rounded(toPlaces: 3))|\(coordinate.longitude.rounded(toPlaces: 3))"
                    guard seen.insert(key).inserted else {
                        return nil
                    }
                    return SearchResult(
                        place: SunclubSelectedUVPlace(
                            displayName: name,
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude
                        )
                    )
                }
                .prefix(8)
                .map { $0 }

                if results.isEmpty {
                    errorMessage = "No matching cities were found. Try a city and region, such as Portland, Oregon."
                }
            } catch {
                errorMessage = "Apple Maps could not complete the search. Check your connection and retry."
            }
            isSearching = false
        }
    }

    private func displayName(for item: MKMapItem, fallback: String) -> String {
        let placemark = item.placemark
        let city = placemark.locality ?? placemark.subAdministrativeArea ?? item.name ?? fallback
        let region = placemark.administrativeArea ?? placemark.country
        guard let region, !region.isEmpty, region.caseInsensitiveCompare(city) != .orderedSame else {
            return city
        }
        return "\(city), \(region)"
    }

    private func select(_ place: SunclubSelectedUVPlace) {
        if onSelect(place) {
            dismiss()
        } else {
            errorMessage = "Sunclub could not save this city. Retry before continuing."
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let scale = pow(10, Double(places))
        return (self * scale).rounded() / scale
    }
}

#Preview {
    CitySearchView { _ in true }
}
