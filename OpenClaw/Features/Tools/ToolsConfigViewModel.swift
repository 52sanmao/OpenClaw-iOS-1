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

        // Load tools-list
        do {
            let response: StatsExecResponse = try await client.statsPost(
                "stats/exec", body: StatsExecRequest(command: "tools-list")
            )
            if let data = response.stdout?.data(using: .utf8) {
                config = ToolsConfig(dto: try JSONDecoder().decode(ToolsListDTO.self, from: data))
            }
        } catch {
            self.error = error
        }

        // Load mcp-list
        do {
            let response: StatsExecResponse = try await client.statsPost(
                "stats/exec", body: StatsExecRequest(command: "mcp-list")
            )
            if let data = response.stdout?.data(using: .utf8) {
                let dto = try JSONDecoder().decode(McpListDTO.self, from: data)
                mcpServers = dto.servers.map { McpServer(name: $0.key, config: $0.value) }.sorted { $0.name < $1.name }
            }
        } catch {
            // Non-fatal — MCP may not be configured
        }
    }

    /// Lazy load — only when user expands MCP section.
    func loadMcpTools() async {
        guard !isLoadingMcpTools && mcpDetails.isEmpty else { return }
        isLoadingMcpTools = true
        defer { isLoadingMcpTools = false }

        do {
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
            }
        } catch {
            // Non-fatal
        }
    }
}
