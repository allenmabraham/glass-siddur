import SwiftUI

/// The page. Loads every prayer under `node`, renders them as one continuous
/// scroll, and floats the reading controls in a glass bar at the bottom.
struct ReaderView: View {
    let nusach: Nusach
    let node: SiddurNode

    @Environment(ReadingSettings.self) private var settings
    @Environment(UserLibrary.self) private var library

    @State private var blocks: [PrayerBlock] = []
    @State private var showTypography = false
    @State private var pinchBase: Double?
    @State private var scrollTarget: String?
    @State private var selectedParagraph: String?
    @State private var contentWidth: CGFloat = 400

    private var loadedCount: Int {
        blocks.filter { if case .loaded = $0.state { true } else { false } }.count
    }

    var body: some View {
        @Bindable var settings = settings
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 28) {
                    if !nusach.hasEnglish && settings.languageMode != .hebrew {
                        noEnglishNotice
                    }
                    ForEach(blocks) { block in
                        PrayerBlockView(block: block, nusach: nusach, selection: $selectedParagraph) { Task { await load(block: block) } }
                            .id(block.id)
                    }
                    attribution
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .environment(\.readerWidth, contentWidth)
            }
            .onGeometryChange(for: CGFloat.self) { proxy in min(proxy.size.width, 800) - 40 } action: { contentWidth = $0 }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(Backdrop(style: .reader))
            .simultaneousGesture(pinchToZoom)
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(target, anchor: .top) }
                scrollTarget = nil
            }
        }
        .navigationTitle(node.title)
        .navigationSubtitle(node.heTitle)
        .inlineTitle()
        .hidesTabBar()
        .keepsScreenAwake(settings.keepScreenAwake)
        .toolbar {
            ToolbarItemGroup(placement: .readerBar) {
                Menu {
                    Picker("Language", selection: $settings.languageMode) {
                        ForEach(LanguageMode.allCases) { mode in
                            Label(mode == .hebrew ? "Hebrew only" : mode == .english ? "English only" : "Hebrew and English", systemImage: mode.symbol).tag(mode)
                        }
                    }
                    if settings.languageMode == .bilingual {
                        Picker("Layout", selection: $settings.bilingualLayout) {
                            ForEach(BilingualLayout.allCases) { Text($0.label).tag($0) }
                        }
                    }
                } label: {
                    Label(settings.languageMode.label, systemImage: "globe")
                        .labelStyle(.titleAndIcon)
                }
                .disabled(!nusach.hasEnglish)
            }
            ToolbarSpacer(.flexible, placement: .readerBar)
            ToolbarItemGroup(placement: .readerBar) {
                if blocks.count > 1 {
                    Menu {
                        ForEach(blocks) { block in
                            Button(block.node.title) { scrollTarget = block.id }
                        }
                    } label: {
                        Label("Jump to", systemImage: "list.bullet")
                    }
                }
                Button {
                    library.toggleBookmark(node, in: nusach)
                } label: {
                    Label("Bookmark", systemImage: library.isBookmarked(node, in: nusach) ? "bookmark.fill" : "bookmark")
                }
                .sensoryFeedback(.impact(weight: .light), trigger: library.isBookmarked(node, in: nusach))
                Button {
                    showTypography = true
                } label: {
                    Label("Text size and fonts", systemImage: "textformat.size")
                }
            }
        }
        .overlay(alignment: .top) { loadingPill }
        .sheet(isPresented: $showTypography) {
            TypographySheet()
        }
        .task(id: node.id) { await loadAll() }
        .modifier(SnapshotHooks(showTypography: $showTypography, selection: $selectedParagraph))
        .onAppear { library.markRead(node, in: nusach) }
    }

    // MARK: - Pieces

    private var noEnglishNotice: some View {
        Label("Sefaria has no English translation for Nusach Ari, so this siddur is shown in Hebrew.", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: .rect(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder private var loadingPill: some View {
        if !blocks.isEmpty && loadedCount < blocks.count && blocks.contains(where: { if case .loading = $0.state { true } else { false } }) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Loading \(loadedCount + 1) of \(blocks.count)")
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var attribution: some View {
        VStack(spacing: 4) {
            Text("Text courtesy of Sefaria")
            if let first = blocks.lazy.compactMap({ block -> PrayerLeafText? in
                if case .loaded(let t) = block.state { return t } else { return nil }
            }).first {
                if let en = first.englishVersionTitle, nusach.hasEnglish { Text(en) }
                if let he = first.hebrewVersionTitle { Text(he) }
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
        .padding(.top, 24)
    }

    private var pinchToZoom: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.02)
            .onChanged { value in
                if pinchBase == nil { pinchBase = settings.fontScale }
                settings.setFontScale((pinchBase ?? 1) * value.magnification)
            }
            .onEnded { _ in pinchBase = nil }
    }

    // MARK: - Loading

    private func loadAll() async {
        let leaves = node.leaves
        blocks = leaves.map { PrayerBlock(node: $0, state: .loading) }
        await withTaskGroup(of: (Int, PrayerBlock.State).self) { group in
            for (index, leaf) in leaves.enumerated() {
                group.addTask {
                    do {
                        let text = try await TextRepository.shared.text(for: leaf.ref)
                        return (index, .loaded(text))
                    } catch {
                        return (index, .failed(error.localizedDescription))
                    }
                }
            }
            for await (index, state) in group {
                guard blocks.indices.contains(index) else { continue }
                withAnimation(.easeOut(duration: 0.2)) { blocks[index].state = state }
            }
        }
    }

    private func load(block: PrayerBlock) async {
        guard let index = blocks.firstIndex(where: { $0.id == block.id }) else { return }
        blocks[index].state = .loading
        do {
            let text = try await TextRepository.shared.text(for: block.node.ref)
            blocks[index].state = .loaded(text)
        } catch {
            blocks[index].state = .failed(error.localizedDescription)
        }
    }
}

/// Snapshot driver hooks; compile to nothing in Release.
private struct SnapshotHooks: ViewModifier {
    @Binding var showTypography: Bool
    @Binding var selection: String?
    func body(content: Content) -> some View {
        #if DEBUG
        content
            .onChange(of: SnapshotDriver.shared.showTypography) { _, show in showTypography = show }
            .onChange(of: SnapshotDriver.shared.selectedRow) { _, row in withAnimation(nil) { selection = row } }
        #else
        content
        #endif
    }
}
