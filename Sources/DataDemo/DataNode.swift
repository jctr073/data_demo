import Foundation

struct DataNode: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let source: String
    let systemImage: String
    let children: [DataNode]?

    static func == (lhs: DataNode, rhs: DataNode) -> Bool {
        lhs.source == rhs.source && lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(source)
        hasher.combine(id)
    }

    static let placeholders: [DataNode] = [
        DataNode(
            id: 1,
            title: "category",
            source: "category",
            systemImage: "folder",
            children: [
                DataNode(
                    id: 2,
                    title: "film",
                    source: "film",
                    systemImage: "film",
                    children: [
                        DataNode(
                            id: 3,
                            title: "actor",
                            source: "actor",
                            systemImage: "person.2",
                            children: nil
                        )
                    ]
                )
            ]
        )
    ]
}

extension DataNode {
    var displayID: String {
        "\(source):\(id)"
    }

    var filmChildren: [DataNode] {
        children?.filter { $0.source == "film" } ?? []
    }

    func contains(_ target: DataNode?) -> Bool {
        guard let target else {
            return false
        }

        if self == target {
            return true
        }

        return children?.contains { $0.contains(target) } ?? false
    }

    func withTitle(_ title: String) -> DataNode {
        DataNode(
            id: id,
            title: title,
            source: source,
            systemImage: systemImage,
            children: children
        )
    }

    func updatingNode(source targetSource: String, id targetID: Int, title: String) -> DataNode {
        if source == targetSource && id == targetID {
            return withTitle(title)
        }

        guard let children else {
            return self
        }

        return DataNode(
            id: id,
            title: self.title,
            source: source,
            systemImage: systemImage,
            children: children.map {
                $0.updatingNode(source: targetSource, id: targetID, title: title)
            }
        )
    }

    func path(to target: DataNode?) -> [DataNode] {
        guard let target else {
            return []
        }

        if self == target {
            return [self]
        }

        for child in children ?? [] {
            let childPath = child.path(to: target)
            if !childPath.isEmpty {
                return [self] + childPath
            }
        }

        return []
    }

    static func path(to target: DataNode?, in nodes: [DataNode]) -> [DataNode] {
        for node in nodes {
            let nodePath = node.path(to: target)
            if !nodePath.isEmpty {
                return nodePath
            }
        }

        return []
    }
}
