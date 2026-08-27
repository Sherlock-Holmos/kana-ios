import SwiftUI

enum LearnMode: String, CaseIterable, Identifiable {
    case kana = "假名"
    case vocabulary = "词汇"
    case grammar = "语法"
    case kanji = "汉字"
    case sentence = "例句"
    case reading = "阅读"
    case listening = "听力"
    case speaking = "跟读"
    case assessment = "阶段测验"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .kana:       return "character.book.closed.fill"
        case .vocabulary: return "textformat.abc"
        case .grammar:    return "list.bullet.rectangle.fill"
        case .kanji:      return "character.square.fill"
        case .sentence:   return "text.bubble.fill"
        case .reading:    return "doc.text.fill"
        case .listening:  return "headphones"
        case .speaking:   return "mic.fill"
        case .assessment: return "checkmark.seal.fill"
        }
    }
}

struct LearnView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("内容") {
                    ForEach([LearnMode.kana, .vocabulary, .grammar, .kanji, .sentence].filter { LearnMode.allCases.contains($0) }) { mode in
                        link(for: mode)
                    }
                }
                Section("技能") {
                    ForEach([LearnMode.reading, .listening, .speaking]) { mode in
                        link(for: mode)
                    }
                }
                Section("评估") {
                    ForEach([LearnMode.assessment]) { mode in
                        link(for: mode)
                    }
                }
            }
            .navigationTitle("学习")
        }
    }

    @ViewBuilder
    private func link(for mode: LearnMode) -> some View {
        NavigationLink {
            destination(for: mode)
        } label: {
            Label(mode.rawValue, systemImage: mode.icon)
                .font(.body)
        }
    }

    @ViewBuilder
    private func destination(for mode: LearnMode) -> some View {
        switch mode {
        case .kana:       KanaBrowserView()
        case .vocabulary: VocabularyFlashcardView()
        case .grammar:    GrammarListView()
        case .kanji:      KanjiListView()
        case .sentence:   SentenceListView()
        case .reading:    ReadingListView()
        case .listening:  ListeningListView()
        case .speaking:   SpeakingView()
        case .assessment: AssessmentView()
        }
    }
}