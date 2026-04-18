import SwiftUI

struct SessionTraceView: View {
    let title: String
    let subtitle: String?
    let sessionKey: String
    let repository: SessionRepository
    let newestFirst: Bool
    var client: GatewayClientProtocol?

    @State private var trace: SessionTrace?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var expandedStepId: String?
    @State private var commentTarget: TraceStep?
    @State private var comments: [TraceComment] = []
    @State private var showSubmitSheet = false

    /// Init from a cron run (existing usage — oldest first).
    init(run: CronRun, repository: CronDetailRepository, jobName: String? = nil, client: GatewayClientProtocol? = nil) {
        self.title = jobName ?? "运行轨迹"
        self.subtitle = run.runAtAbsolute
        self.sessionKey = run.sessionKey ?? run.sessionId ?? ""
        self.repository = SessionRepositoryAdapter(cronRepo: repository)
        self.newestFirst = false
        self.client = client
    }

    /// Init from a session key directly (sessions tab).
    init(sessionKey: String, title: String, subtitle: String? = nil, newestFirst: Bool = false, repository: SessionRepository, client: GatewayClientProtocol? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.sessionKey = sessionKey
        self.repository = repository
        self.newestFirst = newestFirst
        self.client = client
    }

    var body: some View {
        List {
            // Header
            Section {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(AppTypography.body)
                        .fontWeight(.semibold)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.neutral)
                    }
                }
            }

            // Trace steps
            if isLoading && trace == nil {
                Section("执行轨迹") {
                    CardLoadingView(minHeight: 100)
                }
            } else if let trace {
                Section {
                    ForEach(newestFirst ? trace.steps.reversed() : trace.steps) { step in
                        TraceStepRow(
                            step: step,
                            isExpanded: expandedStepId == step.id,
                            onTap: {
                                withAnimation(.snappy(duration: 0.3)) {
                                    expandedStepId = expandedStepId == step.id ? nil : step.id
                                }
                            },
                            onComment: client != nil ? { commentTarget = step } : nil,
                            comments: comments.filter { $0.stepId == step.id },
                            onRemoveComment: { id in comments.removeAll { $0.id == id } }
                        )
                    }

                    if trace.truncated {
                        HStack {
                            Spacer()
                            Label("历史已截断，较早的步骤未显示", systemImage: "ellipsis.circle")
                                .font(AppTypography.micro)
                                .foregroundStyle(AppColors.neutral)
                            Spacer()
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                } header: {
                    HStack {
                        Text("执行轨迹")
                        Text("(\(trace.steps.count) 个步骤)")
                            .foregroundStyle(AppColors.neutral)
                    }
                }
            } else if let error {
                Section("执行轨迹") {
                    CardErrorView(error: error)
                }
            } else if sessionKey.isEmpty {
                Section("执行轨迹") {
                    Text("当前没有可展示的会话数据。")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.neutral)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: title) {
                    if let subtitle {
                        Text(subtitle)
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.neutral)
                    } else if let trace {
                        Text("\(trace.steps.count) 个步骤")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.neutral)
                    } else if isLoading {
                        Text("加载轨迹中…")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.neutral)
                    } else {
                        Text("执行轨迹")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.neutral)
                    }
                }
            }
            if !comments.isEmpty && client != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button { showSubmitSheet = true } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "paperplane.fill")
                            Text("\(comments.count)")
                        }
                        .foregroundStyle(AppColors.primaryAction)
                    }
                }
            }
        }
        .sheet(item: $commentTarget) { step in
            CommentSheet(mode: .paragraph(preview: step.contentPreview) { text in
                comments.append(TraceComment(step: step, text: text))
            })
        }
        .sheet(isPresented: $showSubmitSheet) {
            if let client {
                TraceCommentsSheet(
                    sessionKey: sessionKey,
                    sessionTitle: title,
                    client: client,
                    comments: $comments
                )
            }
        }
        .task {
            guard !sessionKey.isEmpty else { return }
            isLoading = true
            do {
                trace = try await repository.fetchTrace(sessionKey: sessionKey, limit: 100)
                error = nil
            } catch {
                self.error = error
            }
            isLoading = false
        }
    }
}

/// Adapter so CronDetailRepository can be used where SessionRepository is expected.
private struct SessionRepositoryAdapter: SessionRepository {
    let cronRepo: CronDetailRepository

    @MainActor func fetchSessions(limit: Int) async throws -> [SessionEntry] { [] }

    func fetchTrace(sessionKey: String, limit: Int) async throws -> SessionTrace {
        try await cronRepo.fetchSessionTrace(sessionKey: sessionKey, limit: limit)
    }
}
