import Foundation

// MARK: - tools-list

struct ToolsListDTO: Decodable, Sendable {
    let profile: String?
    let allow: [String]?
    let deny: [String]?
    let mcpServers: [String]?
    let native: [NativeTool]?

    struct NativeTool: Decodable, Sendable {
        let name: String
        let group: String?
        let description: String?
    }

    enum CodingKeys: String, CodingKey {
        case profile, allow, deny, native
        case mcpServers = "mcp_servers"
    }
}

// MARK: - mcp-list

struct McpListDTO: Decodable, Sendable {
    let servers: [String: ServerConfig]

    struct ServerConfig: Decodable, Sendable {
        let command: String?
        let args: [String]?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        servers = try container.decode([String: ServerConfig].self)
    }
}

// MARK: - mcp-tools

struct McpToolsDTO: Decodable, Sendable {
    let servers: [String: ServerTools]

    struct ServerTools: Decodable, Sendable {
        let status: String
        let toolCount: Int?
        let tools: [Tool]?
        let error: String?

        enum CodingKeys: String, CodingKey {
            case status, tools, error
            case toolCount = "tool_count"
        }
    }

    struct Tool: Decodable, Sendable {
        let name: String
        let description: String?
    }
}
