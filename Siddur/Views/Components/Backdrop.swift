import SwiftUI

/// Soft animated mesh gradient the glass surfaces float over.
/// Calm enough to read against; rich enough that Liquid Glass has something to refract.
struct Backdrop: View {
    enum Style { case home, reader }
    var style: Style = .home

    @Environment(\.colorScheme) private var colorScheme
    @Environment(ReadingSettings.self) private var settings

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12, paused: style == .reader)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let drift = style == .home ? 0.035 : 0.0
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5 + Float(sin(t * 0.35) * drift), 0.5 + Float(cos(t * 0.27) * drift)], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: palette
            )
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                if style == .home {
                    Circle()
                        .fill(highlight.opacity(colorScheme == .dark ? 0.35 : 0.55))
                        .frame(width: 420, height: 420)
                        .blur(radius: 90)
                        .offset(x: 120, y: -220)
                        .ignoresSafeArea()
                }
            }
        }
    }

    private var isDark: Bool { colorScheme == .dark }
    private var sepia: Bool { settings.theme == .sepia }

    private var highlight: Color {
        isDark ? Color(red: 0.55, green: 0.45, blue: 0.95) : Color(red: 1.0, green: 0.86, blue: 0.62)
    }

    private var palette: [Color] {
        if isDark {
            switch style {
            case .home:
                return [
                    Color(red: 0.07, green: 0.06, blue: 0.16), Color(red: 0.10, green: 0.08, blue: 0.24), Color(red: 0.06, green: 0.09, blue: 0.20),
                    Color(red: 0.12, green: 0.07, blue: 0.22), Color(red: 0.16, green: 0.11, blue: 0.30), Color(red: 0.09, green: 0.10, blue: 0.26),
                    Color(red: 0.04, green: 0.04, blue: 0.10), Color(red: 0.08, green: 0.06, blue: 0.16), Color(red: 0.05, green: 0.05, blue: 0.12),
                ]
            case .reader:
                return Array(repeating: Color(red: 0.07, green: 0.07, blue: 0.10), count: 4)
                    + [Color(red: 0.09, green: 0.08, blue: 0.14)]
                    + Array(repeating: Color(red: 0.05, green: 0.05, blue: 0.08), count: 4)
            }
        }
        if sepia {
            switch style {
            case .home:
                return [
                    Color(red: 0.98, green: 0.93, blue: 0.82), Color(red: 0.99, green: 0.95, blue: 0.86), Color(red: 0.97, green: 0.90, blue: 0.78),
                    Color(red: 0.99, green: 0.94, blue: 0.84), Color(red: 1.00, green: 0.97, blue: 0.90), Color(red: 0.98, green: 0.92, blue: 0.80),
                    Color(red: 0.96, green: 0.90, blue: 0.78), Color(red: 0.98, green: 0.93, blue: 0.82), Color(red: 0.95, green: 0.88, blue: 0.75),
                ]
            case .reader:
                return Array(repeating: Color(red: 0.98, green: 0.95, blue: 0.88), count: 9)
            }
        }
        switch style {
        case .home:
            return [
                Color(red: 0.94, green: 0.95, blue: 1.00), Color(red: 0.98, green: 0.96, blue: 0.92), Color(red: 0.93, green: 0.96, blue: 0.99),
                Color(red: 0.97, green: 0.94, blue: 0.98), Color(red: 1.00, green: 0.98, blue: 0.95), Color(red: 0.92, green: 0.95, blue: 1.00),
                Color(red: 0.95, green: 0.97, blue: 1.00), Color(red: 0.99, green: 0.97, blue: 0.93), Color(red: 0.94, green: 0.96, blue: 1.00),
            ]
        case .reader:
            return Array(repeating: Color(red: 0.985, green: 0.98, blue: 0.97), count: 9)
        }
    }
}
