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
