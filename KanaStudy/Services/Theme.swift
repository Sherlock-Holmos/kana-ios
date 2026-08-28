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

/// Hero typography tokens — used by views that show a Japanese character,
/// phrase, or sentence as the focal point of the screen. Centralizing these
/// stops each view from hardcoding its own 64/72/88/160pt and makes the
/// "Apple-feel" hierarchy consistent across the app.
extension Font {
    /// Single character (one kanji, one kana). Used by KanjiDetailView, the
    /// writing challenge reveal, anywhere we display a single glyph.
    static let heroCharacter = Font.system(size: 96, weight: .light, design: .serif)
    /// Short phrase (1-3 short tokens, like a vocabulary word). Used by
    /// VocabularyFlashcardView, ReviewView card.
    static let heroPhrase = Font.system(size: 56, weight: .medium, design: .serif)
    /// Sentence (full JP sentence). Used by SpeakingView, SentenceDetailView,
    /// ReadingDetailView, ListeningDetailView.
    static let heroSentence = Font.system(size: 28, weight: .medium, design: .serif)
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