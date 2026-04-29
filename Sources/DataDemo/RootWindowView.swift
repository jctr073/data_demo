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

                MainContextPanelView(
                    selection: selectedNode,
                    configuration: configuration,
                    onNodeUpdated: updateNode
                )
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

    @MainActor
    private func updateNode(_ update: DataNodeDisplayUpdate) {
        nodes = nodes.map {
            $0.updatingNode(source: update.source, id: update.id, title: update.title)
        }

        if selectedNode?.source == update.source, selectedNode?.id == update.id {
            selectedNode = selectedNode?.withTitle(update.title)
        }
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
