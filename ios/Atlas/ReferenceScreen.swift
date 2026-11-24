import SwiftUI

struct StateFactCard: View {
    let state: StateFact
    /// A torn bottom edge, for the one card that is the screen's accent.
    var torn = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let image = LearningContent.flag(state) {
                Image(uiImage: image).resizable().scaledToFit()
                    .overlay(Rectangle().strokeBorder(Color.atlasLine))
                    .frame(maxHeight: 150)
                    .accessibilityLabel("Flag of \(state.name)")
            }
            fact("Capital", systemImage: "building.columns") {
                Text(state.capital).font(.system(.title, design: .serif, weight: .bold))
            }
            fact(state.nicknameKind, systemImage: "quote.opening") {
                Text("“\(state.nickname)”").font(.system(.title3, design: .serif, weight: .medium))
            }
            DisclosureGroup("Sources & flag credits") {
                VStack(alignment: .leading, spacing: 8) {
                    Link("Capital and state source", destination: state.sourceURL)
                    Link("Name or slogan source", destination: state.nicknameSource)
                    Link("Flag: \(state.flagLicense)", destination: state.flagSource)
                    Text(state.flagCredit).font(.caption).foregroundStyle(Color.atlasMuted)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            }.font(.subheadline.weight(.medium))
        }.buttonStyle(SecondaryButtonStyle()).padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, torn ? TornPaper.depth : 0)
            .atlasCard(torn: torn ? .bottom : [], seed: Voice.seed(state.id))
    }

    private func fact<Value: View>(_ title: String, systemImage: String, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage).font(.footnote.weight(.semibold)).foregroundStyle(Color.atlasMuted)
            value().fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
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
            .listRowBackground(Color.atlasPaper)
            if !search.isEmpty && (category == "States" ? matchingStates.isEmpty : matchingPlaces.isEmpty) {
                ContentUnavailableView("Not in the atlas", systemImage: "book.closed",
                                       description: Text("Nothing matches “\(search)”. Try another spelling."))
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("reference-no-results")
            } else if category == "States" {
                ForEach(matchingStates) { state in
                    NavigationLink {
                        ScrollView { StateFactCard(state: state, torn: true).padding(20) }
                            .atlasScreen(AtlasCamera(longitude: state.capitalCoordinate.longitude,
                                                     latitude: state.capitalCoordinate.latitude,
                                                     span: AtlasCamera.pack(pack.id).span / 2.5))
                            .navigationTitle(state.name)
                    } label: {
                        HStack(spacing: 14) {
                            if let image = LearningContent.flag(state) {
                                Image(uiImage: image).resizable().scaledToFill().frame(width: 48, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.atlasLine))
                                    .accessibilityHidden(true)
                            }
                            VStack(alignment: .leading) {
                                Text(state.name).font(.headline)
                                Text(state.capital).font(.subheadline).foregroundStyle(Color.atlasMuted)
                            }
                        }.frame(minHeight: 52)
                    }.accessibilityIdentifier("state-fact-\(state.id)")
                }
                .listRowBackground(Color.atlasPaper)
            } else {
                Section {
                    ForEach(matchingPlaces) { place in
                        NavigationLink { PlaceDetail(pack: pack, place: place) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(place.name).font(.system(.headline, design: .serif, weight: .bold))
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
                        .font(.footnote.monospaced()).foregroundStyle(Color.atlasInk).textCase(nil).labelTape()
                }
                .listRowBackground(Color.atlasPaper)
            }
        }.scrollContentBackground(.hidden)
            .atlasParallax()
            .atlasScreen(AtlasCamera.pack(pack.id).nudged(longitude: -0.2, latitude: 0.1, zoom: 1.2))
            .foregroundStyle(Color.atlasInk)
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
                Text(place.name).font(.system(.largeTitle, design: .serif, weight: .black)).titleTape()
                    .accessibilityAddTraits(.isHeader)
                MapView(pack: pack, acceptsAnswers: false,
                        target: MapPin(coordinate: place.coordinate, regionID: place.stateID)) { _ in }
                details
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .atlasScreen(AtlasCamera(longitude: place.coordinate.longitude, latitude: place.coordinate.latitude,
                                 span: AtlasCamera.pack(pack.id).span / 3))
        .foregroundStyle(Color.atlasInk)
        .buttonStyle(SecondaryButtonStyle()).navigationBarTitleDisplayMode(.inline)
    }

    /// Everything to read sits on one sheet of paper; links on the raw map would be too faint.
    private var details: some View {
            VStack(alignment: .leading, spacing: 14) {
                Text("A marks the reference location.").font(.subheadline)
                if let rank = place.rank {
                    Text("\(place.populationLabel) residents").font(.system(.title2, design: .serif, weight: .bold))
                    Text("Population rank \(rank) · \(place.populationDate ?? "")")
                    Text(place.populationDefinition ?? "City population").font(.footnote)
                    Link("Official population source", destination: URL(string: place.country == "US" ?
                        "https://www.census.gov/data/tables/time-series/demo/popest/2020s-total-cities-and-towns.html" :
                        "https://service.destatis.de/DE/barchart_race/BarChartRace500k_Berlin_1955-2024.html")!)
                }
                if let definition = place.pointDefinition { Text(definition).font(.subheadline) }
                Text("Latitude \(place.coordinate.latitude.formatted(.number.precision(.fractionLength(4)))), longitude \(place.coordinate.longitude.formatted(.number.precision(.fractionLength(4))))")
                    .font(.subheadline).textSelection(.enabled)
                Link("Coordinate source", destination: place.sourceURL)
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .atlasCard()
    }
}
