import SwiftUI

enum LearnMode: String, CaseIterable, Identifiable {
    case kana = "假名"
    case vocabulary = "词汇"
    case grammar = "语法"
    case kanji = "汉字"
    case sentence = "例句"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .kana:       return "character.book.closed.fill"
        case .vocabulary: return "textformat.abc"
        case .grammar:    return "list.bullet.rectangle.fill"
        case .kanji:      return "character.square.fill"
        case .sentence:   return "text.bubble.fill"
        }
    }
}

struct LearnView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(LearnMode.allCases) { mode in
                    NavigationLink {
                        switch mode {
                        case .kana:       KanaBrowserView()
                        case .vocabulary: VocabularyFlashcardView()
                        case .grammar:    PlaceholderView(title: "语法学习", subtitle: "待实现：grammar.json 已加载到 bundle。")
                        case .kanji:      PlaceholderView(title: "汉字学习", subtitle: "待实现：kanji.json 已加载到 bundle。")
                        case .sentence:   PlaceholderView(title: "例句学习", subtitle: "待实现：sentence.json 已加载到 bundle。")
                        }
                    } label: {
                        Label(mode.rawValue, systemImage: mode.icon)
                            .font(.body)
                    }
                }
            }
            .navigationTitle("学习")
        }
    }
}