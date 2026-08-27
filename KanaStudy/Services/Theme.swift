import SwiftUI

/// App-wide palette overrides. Replaces SwiftUI's adaptive .secondary / .tertiary
/// which can be washed out in light mode, with concrete colors that stay readable.
extension Color {
    /// Secondary text — darker than SwiftUI's default so captions and subtitles
    /// stay readable in light mode.
    static let textSecondary = Color(red: 0.32, green: 0.32, blue: 0.36)
    /// Tertiary text — used for hints and timestamps.
    static let textTertiary = Color(red: 0.48, green: 0.48, blue: 0.52)
    /// Icon background when the icon itself should pop.
    static let iconAccent = Color.accentColor
}

/// Make a label/icon look fully saturated (used for `Image(systemName:)` in toolbars and rows).
struct IconProminent: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.tint)
            .fontWeight(.semibold)
    }
}

extension View {
    /// Tint and slightly weight an icon so it reads better against secondary surfaces.
    func iconProminent() -> some View { modifier(IconProminent()) }
}