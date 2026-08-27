import SwiftUI

struct PlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}