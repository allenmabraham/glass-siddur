import SwiftUI
import Observation

@MainActor
@Observable
final class DownloadManager {
    var progress: Double = 0
    var isRunning = false
    var cacheBytes = 0

    func refreshSize() {
        Task { cacheBytes = await TextRepository.shared.diskCacheSize() }
    }

    func download(_ nusach: Nusach) {
        guard !isRunning else { return }
        isRunning = true
        progress = 0
        let refs = SiddurLibrary.root(for: nusach).leaves.map(\.ref)
        Task {
            await TextRepository.shared.prefetch(refs: refs) { value in
                Task { @MainActor in self.progress = value }
            }
            isRunning = false
            refreshSize()
        }
    }

    func clear() {
        Task {
            await TextRepository.shared.clearDiskCache()
            refreshSize()
        }
    }
}

struct SettingsView: View {
    @Environment(ReadingSettings.self) private var settings
    @Environment(LocationService.self) private var location
    @Environment(\.dismiss) private var dismiss
    @State private var downloads = DownloadManager()

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Nusach") {
                    Picker("Prayer rite", selection: $settings.nusach) {
                        ForEach(Nusach.allCases) { n in
                            VStack(alignment: .leading) {
                                Text("\(n.displayName) · \(n.hebrewName)")
                                Text(n.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(n)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Reading") {
                    Picker("Language", selection: $settings.languageMode) {
                        ForEach(LanguageMode.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Bilingual layout", selection: $settings.bilingualLayout) {
                        ForEach(BilingualLayout.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Appearance", selection: $settings.theme) {
                        ForEach(ReaderTheme.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Keep screen awake while reading", isOn: $settings.keepScreenAwake)
                }

                Section {
                    Toggle("Use location for sunrise & sunset", isOn: $settings.useLocation)
                        .onChange(of: settings.useLocation) { _, on in if on { location.requestIfNeeded() } }
                    if settings.useLocation {
                        let m = JewishClock(location: location.coordinate).moment()
                        if let rise = m.sunrise, let set = m.sunset {
                            LabeledContent("Sunrise", value: rise.formatted(date: .omitted, time: .shortened))
                            LabeledContent("Sunset", value: set.formatted(date: .omitted, time: .shortened))
                        } else if !location.isAuthorized {
                            Text("Location access is off. Enable it in Settings to compute local times.")
                                .font(.footnote).foregroundStyle(.secondary)
                        } else {
                            Text("Waiting for location…").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Prayer times")
                } footer: {
                    Text("Without location, the app assumes sunrise at 6:00 and sunset at 18:30 when choosing the service to suggest.")
                }

                Section {
                    Button {
                        downloads.download(settings.nusach)
                    } label: {
                        HStack {
                            Label("Download all of \(settings.nusach.displayName)", systemImage: "arrow.down.circle")
                            Spacer()
                            if downloads.isRunning {
                                ProgressView(value: downloads.progress).frame(width: 80)
                            }
                        }
                    }
                    .disabled(downloads.isRunning)
                    LabeledContent("Stored offline", value: ByteCountFormatter.string(fromByteCount: Int64(downloads.cacheBytes), countStyle: .file))
                    Button("Clear downloaded text", role: .destructive) { downloads.clear() }
                } header: {
                    Text("Offline")
                } footer: {
                    Text("Every prayer you open is kept on this device. Download a whole siddur once and it works without a connection.")
                }

                Section("About") {
                    Link(destination: URL(string: "https://www.sefaria.org")!) {
                        LabeledContent("Texts", value: "Sefaria")
                    }
                    LabeledContent("Hebrew", value: "Metsudah Siddur (1981)")
                    LabeledContent("Translation", value: "Based on the Metsudah linear siddur, Avrohom Davis")
                    LabeledContent("Hebrew fonts", value: "Frank Ruhl Libre, David Libre, Noto Serif Hebrew (OFL)")
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Backdrop(style: .home))
            .navigationTitle("Settings")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.buttonStyle(.glassProminent).tint(.brand)
                }
            }
            .onAppear { downloads.refreshSize() }
        }
    }
}
