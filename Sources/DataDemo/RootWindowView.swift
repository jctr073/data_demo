import SwiftUI

struct RootWindowView: View {
    let configuration: AppConfiguration
    @Binding var selectedNode: DataNode?
    @State private var nodes: [DataNode] = []
    @State private var searchText = ""
    @State private var isLoadingNodes = false
    @State private var loadingError: String?

    var body: some View {
        HSplitView {
            SearchFirstSidebarView(
                nodes: nodes,
                isLoading: isLoadingNodes,
                errorMessage: loadingError,
                searchText: $searchText,
                selection: $selectedNode
            )
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 440)

            MainContextPanelView(
                selection: selectedNode,
                breadcrumb: DataNode.path(to: selectedNode, in: nodes),
                configuration: configuration,
                onNodeUpdated: updateNode
            )
            .frame(minWidth: 600)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
                selectedNode = Self.firstFilm(in: loadedNodes) ?? loadedNodes.first
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

    private static func firstFilm(in nodes: [DataNode]) -> DataNode? {
        for node in nodes {
            if node.source == "film" {
                return node
            }

            if let film = firstFilm(in: node.children ?? []) {
                return film
            }
        }

        return nil
    }
}

private struct SearchFirstSidebarView: View {
    let nodes: [DataNode]
    let isLoading: Bool
    let errorMessage: String?
    @Binding var searchText: String
    @Binding var selection: DataNode?
    @State private var expandedCategoryID: String?
    @FocusState private var isSearchFocused: Bool

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedSearchText.isEmpty
    }

    private var activeCategory: DataNode? {
        DataNode.path(to: selection, in: nodes).first(where: { $0.source == "category" }) ?? nodes.first
    }

    private var selectedFilm: DataNode? {
        DataNode.path(to: selection, in: nodes).first(where: { $0.source == "film" })
    }

    private var searchGroups: [SidebarSearchGroup] {
        guard isSearching else {
            return []
        }

        return nodes.compactMap { category in
            let matchingFilms = category.filmChildren.filter { film in
                film.title.localizedCaseInsensitiveContains(trimmedSearchText)
                    || category.title.localizedCaseInsensitiveContains(trimmedSearchText)
            }

            guard !matchingFilms.isEmpty else {
                return nil
            }

            return SidebarSearchGroup(category: category, films: matchingFilms)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
                .padding(.horizontal, 20)
                .padding(.top, 26)
                .padding(.bottom, 20)

            sidebarContent
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: activeCategory?.displayID, initial: true) { _, newCategoryID in
            guard expandedCategoryID == nil else {
                return
            }

            expandedCategoryID = newCategoryID
        }
        .onChange(of: isSearching) { _, isSearching in
            if !isSearching {
                expandedCategoryID = activeCategory?.displayID
            }
        }
    }

    private var searchField: some View {
        ZStack {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Search films...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .focused($isSearchFocused)
                    .onSubmit(selectFirstSearchResult)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .help("Clear search")
                }

                Text("⌘K")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor))
                    }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor))
            }

            Button {
                isSearchFocused = true
            } label: {
                EmptyView()
            }
            .keyboardShortcut("k", modifiers: .command)
            .buttonStyle(.plain)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var sidebarContent: some View {
        if isLoading {
            SidebarMessageView(title: "Loading films", systemImage: "hourglass")
                .padding(.horizontal, 20)
        } else if let errorMessage {
            SidebarMessageView(title: errorMessage, systemImage: "exclamationmark.triangle", isError: true)
                .padding(.horizontal, 20)
        } else if nodes.isEmpty {
            SidebarMessageView(title: "No films found", systemImage: "tray")
                .padding(.horizontal, 20)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if isSearching {
                        searchResults
                    } else {
                        categoryBrowser
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private var categoryBrowser: some View {
        VStack(alignment: .leading, spacing: 10) {
            SidebarSectionLabel("Categories")

            VStack(alignment: .leading, spacing: 4) {
                ForEach(nodes) { category in
                    VStack(alignment: .leading, spacing: 4) {
                        SidebarCategoryRow(
                            title: category.title,
                            count: category.filmChildren.count,
                            isActive: category == activeCategory,
                            action: { selectCategory(category) }
                        )

                        if category.displayID == expandedCategoryID {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(category.filmChildren) { film in
                                    SidebarFilmRow(
                                        title: film.title,
                                        isSelected: film == selectedFilm,
                                        action: { selection = film }
                                    )
                                }
                            }
                            .padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if searchGroups.isEmpty {
            SidebarMessageView(title: "No matching films", systemImage: "magnifyingglass")
                .padding(.top, 6)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                SidebarSectionLabel("Results")

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(searchGroups) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            SidebarCategoryRow(
                                title: group.category.title,
                                count: group.films.count,
                                isActive: group.category == activeCategory,
                                action: { selectSearchCategory(group) }
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(group.films) { film in
                                    SidebarFilmRow(
                                        title: film.title,
                                        isSelected: film == selectedFilm,
                                        action: {
                                            expandedCategoryID = group.category.displayID
                                            selection = film
                                        }
                                    )
                                }
                            }
                            .padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    private func selectCategory(_ category: DataNode) {
        if expandedCategoryID == category.displayID {
            expandedCategoryID = nil
            return
        }

        expandedCategoryID = category.displayID
        selection = category.filmChildren.first ?? category
    }

    private func selectSearchCategory(_ group: SidebarSearchGroup) {
        expandedCategoryID = group.category.displayID
        selection = group.films.first ?? group.category
    }

    private func selectFirstSearchResult() {
        guard let firstGroup = searchGroups.first, let firstFilm = firstGroup.films.first else {
            return
        }

        expandedCategoryID = firstGroup.category.displayID
        selection = firstFilm
    }
}

private struct SidebarSearchGroup: Identifiable {
    let category: DataNode
    let films: [DataNode]

    var id: String {
        category.displayID
    }
}

private struct SidebarSectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
    }
}

private struct SidebarCategoryRow: View {
    let title: String
    let count: Int
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .lineLimit(1)

                Spacer(minLength: 10)

                Text("\(count)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.18))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SidebarFilmRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct SidebarMessageView: View {
    let title: String
    let systemImage: String
    var isError = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(isError ? Color.red : Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
