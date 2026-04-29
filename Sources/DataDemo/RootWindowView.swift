import SwiftUI

struct RootWindowView: View {
    let configuration: AppConfiguration
    @Binding var selectedNode: DataNode?
    @State private var nodes: [DataNode] = []
    @State private var isLoadingNodes = false
    @State private var loadingError: String?

    var body: some View {
        VStack(spacing: 0) {
            ToolPanelView(configuration: configuration)

            HSplitView {
                NavTreePanelView(
                    nodes: nodes,
                    isLoading: isLoadingNodes,
                    errorMessage: loadingError,
                    selection: $selectedNode
                )
                    .frame(minWidth: 220, idealWidth: 260, maxWidth: 360)

                MainContextPanelView(selection: selectedNode, configuration: configuration)
                    .frame(minWidth: 560)
            }
        }
        .task {
            await loadNodes()
        }
    }

    @MainActor
    private func loadNodes() async {
        isLoadingNodes = true
        loadingError = nil

        do {
            let loadedNodes = try await DataNodeRepository(configuration: configuration.database).loadNodes()
            nodes = loadedNodes
            if selectedNode == nil || !loadedNodes.contains(where: { $0.contains(selectedNode) }) {
                selectedNode = loadedNodes.first
            }
        } catch {
            nodes = []
            selectedNode = nil
            loadingError = error.localizedDescription
        }

        isLoadingNodes = false
    }
}

private struct ToolPanelView: View {
    let configuration: AppConfiguration

    var body: some View {
        HStack(spacing: 12) {
            Label("Data Demo", systemImage: "tablecells")
                .font(.headline)

            Divider()
                .frame(height: 22)

            Label("Postgres configured", systemImage: "externaldrive.connected.to.line.below")
                .foregroundStyle(.secondary)

            Spacer()

            Text(configuration.environment.displayText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct NavTreePanelView: View {
    let nodes: [DataNode]
    let isLoading: Bool
    let errorMessage: String?
    @Binding var selection: DataNode?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("navTreePanel")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            List(selection: $selection) {
                if isLoading {
                    Label("Loading data", systemImage: "hourglass")
                        .foregroundStyle(.secondary)
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                } else if nodes.isEmpty {
                    Label("No data", systemImage: "tray")
                        .foregroundStyle(.secondary)
                } else {
                    OutlineGroup(nodes, children: \.children) { node in
                        Label(node.title, systemImage: node.systemImage)
                            .tag(node)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private extension DataNode {
    func contains(_ target: DataNode?) -> Bool {
        guard let target else {
            return false
        }

        if self == target {
            return true
        }

        return children?.contains { $0.contains(target) } ?? false
    }
}

private struct MainContextPanelView: View {
    let selection: DataNode?
    let configuration: AppConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("mainContextPanel")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(selection?.title ?? "No selection")
                    .font(.system(size: 34, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "Database", value: configuration.database.database)
                DetailRow(label: "Host", value: "\(configuration.database.host):\(configuration.database.port)")
                DetailRow(label: "Adapter", value: "PostgresNIO")
                DetailRow(label: "Selected node", value: selection?.displayID ?? "none")
            }

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private extension DataNode {
    var displayID: String {
        "\(source):\(id)"
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(value)
                .font(.callout)
                .textSelection(.enabled)
        }
    }
}
