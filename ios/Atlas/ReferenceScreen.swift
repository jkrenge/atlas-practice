import SwiftUI

struct StateFactCard: View {
    let state: StateFact
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let image = LearningContent.flag(state) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 150)
                    .accessibilityLabel("Flag of \(state.name)")
            }
            Divider().padding(.vertical, 4)
            AtlasSectionLabel(title: "Capital")
            Text(state.capital).font(.system(.title, design: .default, weight: .semibold))
            VStack(alignment: .leading, spacing: 6) {
                Text(state.nicknameKind).font(.caption.weight(.semibold)).foregroundStyle(Color.atlasMuted)
                Text(state.nickname).font(.title3)
            }
            DisclosureGroup("Sources & flag credits") {
                VStack(alignment: .leading, spacing: 4) {
                    Link("Capital and state source", destination: state.sourceURL).frame(minHeight: 44)
                    Link("Name or slogan source", destination: state.nicknameSource).frame(minHeight: 44)
                    Link("Flag: \(state.flagLicense)", destination: state.flagSource).frame(minHeight: 44)
                    Text(state.flagCredit).font(.caption).foregroundStyle(Color.atlasMuted)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.font(.subheadline).padding(12).atlasOutline(cornerRadius: 14)
        }.buttonStyle(SecondaryButtonStyle()).padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.atlasSurface, in: RoundedRectangle(cornerRadius: 28))
    }
}

struct ReferenceScreen: View {
    let pack: MapPack
    let content: LearningContent
    @State private var category = "States"
    @State private var search = ""
    private var matchingStates: [StateFact] {
        content.states(in: pack).filter { matches($0.name) || matches($0.capital) }
    }
    private var matchingPlaces: [PlaceFact] {
        content.places(in: pack, landmarks: category == "Sights").filter { matches($0.name) }
    }
    var body: some View {
        List {
            Section {
                Picker("Content", selection: $category) {
                    Text("States").tag("States")
                    Text("Cities").tag("Cities")
                    Text("Sights").tag("Sights")
                }.pickerStyle(.segmented)
            }
            if !search.isEmpty && (category == "States" ? matchingStates.isEmpty : matchingPlaces.isEmpty) {
                ContentUnavailableView.search(text: search)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("reference-no-results")
            } else if category == "States" {
                ForEach(matchingStates) { state in
                    NavigationLink {
                        ScrollView { StateFactCard(state: state).padding(20) }
                            .background(Color.atlasPaper).navigationTitle(state.name)
                    } label: {
                        HStack(spacing: 14) {
                            if let image = LearningContent.flag(state) {
                                Image(uiImage: image).resizable().scaledToFit().frame(width: 54, height: 40).accessibilityHidden(true)
                            }
                            VStack(alignment: .leading) {
                                Text(state.name).font(.headline)
                                Text(state.capital).font(.subheadline).foregroundStyle(Color.atlasMuted)
                            }
                        }.frame(minHeight: 52)
                    }.accessibilityIdentifier("state-fact-\(state.id)")
                }
            } else {
                Section {
                    ForEach(matchingPlaces) { place in
                        NavigationLink { PlaceDetail(pack: pack, place: place) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(place.name).font(.headline)
                                if let rank = place.rank {
                                    Text("#\(rank) · \(place.populationLabel) residents").font(.subheadline).foregroundStyle(Color.atlasMuted)
                                }
                            }.frame(minHeight: 48)
                        }.accessibilityIdentifier("place-fact-\(place.id)")
                    }
                } footer: {
                    Text(category == "Sights" ? "A curated learning collection, not a popularity ranking." :
                         pack.id == "us-states" ? "Census Vintage 2025 · July 1, 2025. City populations include the published consolidated-government balances and Washington, DC." :
                         "Destatis · December 31, 2024. Population within municipal boundaries, based on the 2022 census.")
                }
            }
        }.scrollContentBackground(.hidden).background(Color.atlasPaper).foregroundStyle(Color.atlasInk)
            .searchable(text: $search, prompt: "Search \(category.lowercased())")
            .navigationTitle("Learn the details").navigationBarTitleDisplayMode(.inline)
    }
    private func matches(_ value: String) -> Bool { search.isEmpty || value.localizedCaseInsensitiveContains(search) }
}

struct PlaceDetail: View {
    let pack: MapPack
    let place: PlaceFact
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(place.name).font(.system(.largeTitle, design: .default, weight: .semibold))
                MapView(pack: pack, acceptsAnswers: false,
                        target: MapPin(coordinate: place.coordinate, regionID: place.stateID)) { _ in }
                Text("A marks the reference location.").font(.subheadline)
                if let rank = place.rank {
                    Text("\(place.populationLabel) residents").font(.title2.weight(.semibold))
                    Text("Population rank \(rank) · \(place.populationDate ?? "")")
                    Text(place.populationDefinition ?? "City population").font(.footnote)
                    Link("Official population source", destination: URL(string: place.country == "US" ?
                        "https://www.census.gov/data/tables/time-series/demo/popest/2020s-total-cities-and-towns.html" :
                        "https://service.destatis.de/DE/barchart_race/BarChartRace500k_Berlin_1955-2024.html")!).frame(minHeight: 44)
                }
                if let definition = place.pointDefinition { Text(definition).font(.subheadline) }
                Text("Latitude \(place.coordinate.latitude.formatted(.number.precision(.fractionLength(4)))), longitude \(place.coordinate.longitude.formatted(.number.precision(.fractionLength(4))))")
                    .font(.subheadline).textSelection(.enabled)
                Link("Coordinate source", destination: place.sourceURL).frame(minHeight: 44)
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(Color.atlasPaper).foregroundStyle(Color.atlasInk)
            .buttonStyle(SecondaryButtonStyle()).navigationBarTitleDisplayMode(.inline)
    }
}
