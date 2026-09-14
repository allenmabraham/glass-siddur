import SwiftUI
import Observation

struct SettingsView: View {
    @Environment(ReadingSettings.self) private var settings
    @Environment(LocationService.self) private var location
    @Environment(\.dismiss) private var dismiss

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
                    LabeledContent("Prayers included", value: "\(Nusach.allCases.reduce(0) { $0 + BundledTexts.count(for: $1) })")
                    ForEach(Nusach.allCases) { n in
                        LabeledContent(n.displayName, value: "\(BundledTexts.count(for: n))")
                    }
                } header: {
                    Text("Offline")
                } footer: {
                    Text("Every prayer of every nusach is built into the app. Nothing needs to be downloaded, and no connection is required.")
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
        }
    }
}
