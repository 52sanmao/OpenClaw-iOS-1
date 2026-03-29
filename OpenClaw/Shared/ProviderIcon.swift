import SwiftUI

/// Small provider logo icon. Extracts provider from a full model string like "anthropic/claude-sonnet-4-6".
struct ProviderIcon: View {
    let provider: String
    var size: CGFloat = 14

    /// Init from a full model string — extracts the provider prefix.
    init(model: String, size: CGFloat = 14) {
        self.provider = Self.extractProvider(from: model)
        self.size = size
    }

    /// Init from a known provider name directly.
    init(provider: String, size: CGFloat = 14) {
        self.provider = provider
        self.size = size
    }

    private var imageName: String? {
        switch provider {
        case "anthropic":                 "claude"
        case "github-copilot", "github":  "github"
        case "openai":                    "openai"
        case "google":                    "gemini"
        case "openclaw":                  "openclaw"
        default:                          nil
        }
    }

    var body: some View {
        if let imageName {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "cpu")
                .font(.system(size: size * 0.75))
                .foregroundStyle(AppColors.neutral)
                .frame(width: size, height: size)
        }
    }

    static func extractProvider(from model: String) -> String {
        guard model.contains("/") else { return model }
        return String(model.split(separator: "/").first ?? "")
    }
}
