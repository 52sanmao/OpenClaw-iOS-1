import Foundation
import Observation

@Observable
@MainActor
final class ToolsConfigViewModel {
    var config: ToolsConfig?
    var mcpServers: [McpServer] = []
    var mcpDetails: [String: McpServerDetail] = [:]
    var isLoading = false
    var isLoadingMcpTools = false
    var error: Error?

    private let client: GatewayClientProtocol

    init(client: GatewayClientProtocol) {
        self.client = client
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        error = nil
        config = nil
        mcpServers = []
        mcpDetails = [:]
        AppLogStore.shared.append("ToolsConfigViewModel: 开始加载工具配置与 MCP 列表")

        // Load tools-list
        do {
            AppLogStore.shared.append("ToolsConfigViewModel: 开始读取 tools-list")
            let response: StatsExecResponse = try await client.statsPost(
                "stats/exec", body: StatsExecRequest(command: "tools-list")
            )
            if let data = response.stdout?.data(using: .utf8) {
                config = ToolsConfig(dto: try JSONDecoder().decode(ToolsListDTO.self, from: data))
                AppLogStore.shared.append("ToolsConfigViewModel: tools-list 加载成功 groups=\(config?.groups.count ?? 0)")
            }
        } catch let gatewayError as GatewayError {
            AppLogStore.shared.append("ToolsConfigViewModel: tools-list 加载失败 error=\(gatewayError.localizedDescription)")
            if case .httpError(404, _) = gatewayError {
                self.error = gatewayError
                return
            }
            self.error = gatewayError
        } catch {
            AppLogStore.shared.append("ToolsConfigViewModel: tools-list 加载失败 error=\(error.localizedDescription)")
            self.error = error
        }

        // Load mcp-list
        do {
            AppLogStore.shared.append("ToolsConfigViewModel: 开始读取 mcp-list")
            let response: StatsExecResponse = try await client.statsPost(
                "stats/exec", body: StatsExecRequest(command: "mcp-list")
            )
            if let data = response.stdout?.data(using: .utf8) {
                let dto = try JSONDecoder().decode(McpListDTO.self, from: data)
                mcpServers = dto.servers.map { McpServer(name: $0.key, config: $0.value) }.sorted { $0.name < $1.name }
                AppLogStore.shared.append("ToolsConfigViewModel: mcp-list 加载成功 count=\(mcpServers.count)")
            }
        } catch {
            AppLogStore.shared.append("ToolsConfigViewModel: mcp-list 加载失败 error=\(error.localizedDescription)")
            // Non-fatal — MCP may not be configured
        }
    }

    var unavailableDescription: String {
        "此页面依赖 /stats/exec 扩展接口。当前 IronClaw 部署未启用该能力，所以无法读取工具白名单、MCP 服务和服务端配置；这不影响聊天主链路与 routines。"
    }

    /// Lazy load — only when user expands MCP section.
    func loadMcpTools() async {
        guard !isLoadingMcpTools && mcpDetails.isEmpty else { return }
        isLoadingMcpTools = true
        defer { isLoadingMcpTools = false }

        do {
            AppLogStore.shared.append("ToolsConfigViewModel: 开始读取 mcp-tools")
            let response: StatsExecResponse = try await client.statsPost(
                "stats/exec", body: StatsExecRequest(command: "mcp-tools")
            )
            if let data = response.stdout?.data(using: .utf8) {
                let dto = try JSONDecoder().decode(McpToolsDTO.self, from: data)
                for (name, serverTools) in dto.servers {
                    mcpDetails[name] = McpServerDetail(
                        status: serverTools.status,
                        tools: serverTools.tools ?? [],
                        error: serverTools.error
                    )
                }
                AppLogStore.shared.append("ToolsConfigViewModel: mcp-tools 加载成功 servers=\(mcpDetails.count)")
            }
        } catch {
            AppLogStore.shared.append("ToolsConfigViewModel: mcp-tools 加载失败 error=\(error.localizedDescription)")
            // Non-fatal
        }
    }
}
