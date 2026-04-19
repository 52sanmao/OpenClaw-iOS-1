import Foundation

// MARK: - Models Status (legacy — kept for backward compatibility with stats/exec fallback)

struct ModelsStatusDTO: Decodable, Sendable {
    let defaultModel: String?
    let resolvedDefault: String?
    let fallbacks: [String]?
    let imageModel: String?
    let aliases: [String: String]?
}

// MARK: - Agents List (legacy — kept for backward compatibility)

struct AgentDTO: Decodable, Sendable {
    let id: String
    let name: String?
    let identityName: String?
    let identityEmoji: String?
    let model: String?
    let isDefault: Bool?
}

// MARK: - Channels List (legacy — kept for backward compatibility)

struct ChannelsListDTO: Decodable, Sendable {
    let chat: [String: [String]]?
    let usage: UsageInfo?

    struct UsageInfo: Decodable, Sendable {
        let updatedAt: Int?
        let providers: [ProviderUsage]?
    }

    struct ProviderUsage: Decodable, Sendable {
        let provider: String
        let displayName: String?
        let plan: String?
        let windows: [UsageWindow]?
    }

    struct UsageWindow: Decodable, Sendable {
        let label: String
        let usedPercent: Double
    }
}

// MARK: - /api/llm/providers (real REST)

struct LLMProviderDTO: Decodable, Sendable {
    let id: String
    let name: String
    let adapter: String?
    let baseUrl: String?
    let builtin: Bool?
    let defaultModel: String?
    let apiKeyRequired: Bool?
    let canListModels: Bool?
    let hasApiKey: Bool?
    let envModel: String?
    let envBaseUrl: String?
}

// MARK: - /api/extensions (real REST)

struct ExtensionListResponseDTO: Decodable, Sendable {
    let extensions: [ExtensionInfoDTO]
}

struct ExtensionInfoDTO: Decodable, Sendable {
    let name: String
    let displayName: String?
    let kind: String              // wasm_channel | channel_relay | mcp_server | wasm_tool | acp_agent
    let description: String?
    let url: String?
    let authenticated: Bool
    let active: Bool
    let tools: [String]?
    let needsSetup: Bool?
    let hasAuth: Bool?
    let activationStatus: String? // "Active" | "Configured" | "Installed" | "Failed"
    let activationError: String?
    let version: String?
}

// MARK: - /api/extensions/tools (real REST)

struct ExtensionToolListResponseDTO: Decodable, Sendable {
    let tools: [ExtensionToolDTO]
}

struct ExtensionToolDTO: Decodable, Sendable {
    let name: String
    let description: String?
}

// MARK: - /api/settings/tools (real REST)

struct ToolPermissionsResponseDTO: Decodable, Sendable {
    let tools: [ToolPermissionEntryDTO]
}

struct ToolPermissionEntryDTO: Decodable, Sendable {
    let name: String
    let description: String?
    let currentState: String
    let defaultState: String
    let locked: Bool
    let lockedReason: String?
}
