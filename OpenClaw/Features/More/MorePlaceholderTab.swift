import SwiftUI

struct MoreTab: View {
    let client: GatewayClientProtocol

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("更多", systemImage: "ellipsis.circle")
            } description: {
                Text("更多功能即将上线。")
                    .font(AppTypography.body)
            }
            .navigationTitle("更多")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
