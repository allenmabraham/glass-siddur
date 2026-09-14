import SwiftUI

/// Front screen: what to daven now, quick language/nusach switches, and the services.
struct HomeView: View {
    @Environment(ReadingSettings.self) private var settings
    @Environment(UserLibrary.self) private var library
    @Environment(LocationService.self) private var location
    @State private var showSettings = false

    var body: some View {
        @Bindable var settings = settings
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let moment = JewishClock(now: context.date, location: settings.useLocation ? location.coordinate : nil).moment()
            ScrollView {
                VStack(spacing: 22) {
                    NowCard(moment: moment, nusach: settings.nusach)
                    VStack(spacing: 10) {
                        LanguageModePicker(mode: $settings.languageMode)
                            .disabled(!settings.nusach.hasEnglish)
                            .opacity(settings.nusach.hasEnglish ? 1 : 0.55)
                        NusachPicker(nusach: $settings.nusach)
                    }
                    if let last = library.lastRead, last.nusach == settings.nusach,
                       let node = SiddurLibrary.root(for: last.nusach).node(withID: last.nodeID) {
                        continueCard(node: node, nusach: last.nusach)
                    }
                    servicesGrid(moment: moment)
                    browseAll
                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
            .navigationSubtitle("\(moment.weekdayName) · \(moment.hebrewDateEnglish)")
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(Backdrop(style: .home))
        .navigationTitle("Siddur")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear { if settings.useLocation { location.requestIfNeeded() } }
        .modifier(HomeSnapshotHooks(showSettings: $showSettings))
    }

    private func continueCard(node: SiddurNode, nusach: Nusach) -> some View {
        NavigationLink(value: Route.reader(nusach, node.id)) {
            SurfaceCard(padding: 16, cornerRadius: 22) {
                HStack(spacing: 14) {
                    Image(systemName: "book.pages")
                        .font(.title2)
                        .foregroundStyle(Color.brand)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Continue").font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                        Text(node.title).font(.headline)
                    }
                    Spacer()
                    Text(node.heTitle).font(.body).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func servicesGrid(moment: JewishClock.Moment) -> some View {
        let nusach = settings.nusach
        let slots: [ServiceSlot] = nusach.hasShabbat
            ? [.shacharit, .mincha, .maariv, .kabbalatShabbat, .shabbatShacharit, .shabbatMusaf, .shabbatMincha, .havdalah, .bedtimeShema]
            : [.shacharit, .mincha, .maariv, .bedtimeShema]
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Services", hebrew: "תפילות")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(slots) { slot in
                    if let node = SiddurLibrary.node(for: slot, in: nusach) {
                        NavigationLink(value: Route.reader(nusach, node.id)) {
                            ServiceTile(slot: slot, node: node, highlighted: slot == moment.slot)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var browseAll: some View {
        NavigationLink(value: Route.section(settings.nusach, "root")) {
            SurfaceCard(padding: 16, cornerRadius: 22) {
                HStack {
                    Label("Browse the whole siddur", systemImage: "books.vertical")
                        .font(.headline)
                    Spacer()
                    Text(settings.nusach.hebrewName).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        Text("Texts from Sefaria · Translation based on the Metsudah Siddur")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }
}

/// The hero: the service for this moment, with the Hebrew date.
struct NowCard: View {
    let moment: JewishClock.Moment
    let nusach: Nusach
    @Environment(ReadingSettings.self) private var settings

    private var node: SiddurNode? { SiddurLibrary.node(for: moment.slot, in: nusach) }

    var body: some View {
        SurfaceCard(padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dayLabel)
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(.secondary)
                        Text(moment.hebrewDateHebrew)
                            .font(settings.hebrewFont.font(size: 22))
                    }
                    Spacer()
                    Image(systemName: moment.slot.symbol)
                        .font(.system(size: 30))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.brand)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Now")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text(moment.slot.title)
                            .font(.system(size: 34, weight: .bold, design: .serif))
                        Spacer()
                        Text(moment.slot.hebrewTitle)
                            .font(settings.hebrewFont.boldFont(size: 28) ?? settings.hebrewFont.font(size: 28).weight(.bold))
                    }
                }
                HStack(spacing: 10) {
                    if let node {
                        NavigationLink(value: Route.reader(nusach, node.id)) {
                            Label("Begin", systemImage: "book")
                        }
                        .buttonStyle(.brandGlass)
                    }
                    if moment.isRoshChodesh {
                        badge("Rosh Chodesh", "moon.circle.fill")
                    }
                    Spacer()
                    if let sunset = moment.sunset {
                        Label(sunset.formatted(date: .omitted, time: .shortened), systemImage: "sunset")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var dayLabel: String {
        switch moment.dayType {
        case .weekday: moment.weekdayName
        case .erevShabbat: "Erev Shabbat"
        case .shabbat: "Shabbat Kodesh"
        case .motzaeiShabbat: "Motza'ei Shabbat"
        }
    }

    private func badge(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular.tint(Color.brand.opacity(0.35)), in: .capsule)
    }
}

struct ServiceTile: View {
    let slot: ServiceSlot
    let node: SiddurNode
    let highlighted: Bool
    @Environment(ReadingSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: slot.symbol)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(highlighted ? Color.white : Color.brand)
                Spacer()
                Text(slot.hebrewTitle)
                    .font(settings.hebrewFont.font(size: 17))
                    .foregroundStyle(highlighted ? Color.white.opacity(0.9) : Color.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.title).font(.headline)
                Text("\(node.leafCount) \(node.leafCount == 1 ? "prayer" : "prayers")")
                    .font(.caption)
                    .foregroundStyle(highlighted ? Color.white.opacity(0.85) : Color.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .foregroundStyle(highlighted ? Color.white : Color.primary)
        .background {
            if highlighted {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.brand.gradient)
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.thinMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.35), lineWidth: 0.6)
                .blendMode(.plusLighter)
        }
        .shadow(color: .black.opacity(highlighted ? 0.18 : 0.06), radius: 16, y: 8)
    }
}

/// Snapshot driver hooks; compile to nothing in Release.
private struct HomeSnapshotHooks: ViewModifier {
    @Binding var showSettings: Bool
    func body(content: Content) -> some View {
        #if DEBUG
        content.onChange(of: SnapshotDriver.shared.showSettings) { _, show in showSettings = show }
        #else
        content
        #endif
    }
}
