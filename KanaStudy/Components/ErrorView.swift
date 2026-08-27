import SwiftUI

/// ErrorView — standard failure surface used across content-loading views.
/// Built on ContentUnavailableView (iOS 17+) so it adopts system fonts and dark mode automatically.
struct ErrorView: View {
    let title: String
    let message: String
    let retry: (() -> Void)?

    init(title: String = "加载失败", _ message: String, retry: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.retry = retry
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry {
                Button("重试", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// EmptyView — companion to ErrorView for the "list loaded but contains nothing" state.
struct EmptyContentView: View {
    let title: String
    let message: String
    let systemImage: String
    let action: (label: String, perform: () -> Void)?

    init(_ title: String, systemImage: String = "books.vertical", _ message: String, action: (label: String, perform: () -> Void)? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.action = action
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let action {
                Button(action.label, action: action.perform)
                    .buttonStyle(.bordered)
            }
        }
    }
}