import Foundation
import Observation

@Observable
@MainActor
final class AdminViewModel {
    var modelsConfig: ModelsConfig?
    var agents: [AgentInfo] = []
    var channelsStatus: ChannelsStatus?
    var isLoading = false
    var error: Error?

    private let client: GatewayClientProtocol

    init(client: GatewayClientProtocol) {
        self.client = client
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        error = nil
        modelsConfig = nil
        agents = []
        channelsStatus = nil
        AppLogStore.shared.append("AdminViewModel: 开始加载模型、代理与渠道状态")

        await loadModels()
        if error != nil { return }
        await loadAgents()
        if error != nil { return }
        await loadChannels()
    }

    var unavailableDescription: String {
        "此页面依赖 /stats/exec 管理命令。当前 IronClaw 部署未启用该能力，所以无法读取模型配置、代理列表和渠道状态；这不影响聊天主链路与 routines。"
    }

    private func loadModels() async {
        do {
            AppLogStore.shared.append("AdminViewModel: 开始读取模型配置 stats/exec(models-status)")
            let response: StatsExecResponse = try await client.statsPost(
                "stats/exec", body: StatsExecRequest(command: "models-status")
            )
            if let data = response.stdout?.data(using: .utf8) {
                let dto = try JSONDecoder().decode(ModelsStatusDTO.self, from: data)
                modelsConfig = ModelsConfig(dto: dto)
                AppLogStore.shared.append("AdminViewModel: 模型配置加载成功 aliases=\(dto.aliases.count)")
            }
        } catch {
            AppLogStore.shared.append("AdminViewModel: 模型配置加载失败 error=\(error.localizedDescription)")
            self.error = error
        }
    }

    private func loadAgents() async {
        do {
            AppLogStore.shared.append("AdminViewModel: 开始读取代理列表 stats/exec(agents-list)")
            let response: StatsExecResponse = try await client.statsPost(
                "stats/exec", body: StatsExecRequest(command: "agents-list")
            )
            if let data = response.stdout?.data(using: .utf8) {
                let dtos = try JSONDecoder().decode([AgentDTO].self, from: data)
                agents = dtos.map(AgentInfo.init)
                AppLogStore.shared.append("AdminViewModel: 代理列表加载成功 count=\(agents.count)")
            }
        } catch {
            AppLogStore.shared.append("AdminViewModel: 代理列表加载失败 error=\(error.localizedDescription)")
            self.error = error
        }
    }

    private func loadChannels() async {
        do {
            AppLogStore.shared.append("AdminViewModel: 开始读取渠道状态 stats/exec(channels-list)")
            let response: StatsExecResponse = try await client.statsPost(
                "stats/exec", body: StatsExecRequest(command: "channels-list")
            )
            if let data = response.stdout?.data(using: .utf8) {
                let dto = try JSONDecoder().decode(ChannelsListDTO.self, from: data)
                channelsStatus = ChannelsStatus(dto: dto)
                AppLogStore.shared.append("AdminViewModel: 渠道状态加载成功 channels=\(channelsStatus?.channels.count ?? 0) providers=\(channelsStatus?.providers.count ?? 0)")
            }
        } catch {
            AppLogStore.shared.append("AdminViewModel: 渠道状态加载失败 error=\(error.localizedDescription)")
            self.error = error
        }
    }
}
