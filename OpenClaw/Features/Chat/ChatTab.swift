import SwiftUI

struct ChatTab: View {
    @State private var vm: ChatViewModel
    private let client: GatewayClientProtocol
    private let memoryVM: MemoryViewModel?
    private let cronVM: CronSummaryViewModel?
    private let cronDetailRepository: CronDetailRepository?
    private let accountStore: AccountStore?

    init(
        client: GatewayClientProtocol,
        memoryVM: MemoryViewModel? = nil,
        cronVM: CronSummaryViewModel? = nil,
        cronDetailRepository: CronDetailRepository? = nil,
        accountStore: AccountStore? = nil
    ) {
        _vm = State(initialValue: ChatViewModel(client: client))
        self.client = client
        self.memoryVM = memoryVM
        self.cronVM = cronVM
        self.cronDetailRepository = cronDetailRepository
        self.accountStore = accountStore
    }

    var body: some View {
        ChatView(
            vm: vm,
            client: client,
            memoryVM: memoryVM,
            cronVM: cronVM,
            cronDetailRepository: cronDetailRepository,
            accountStore: accountStore
        )
    }
}
