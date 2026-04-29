import Foundation

struct DataNode: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    let children: [DataNode]?

    static let placeholders: [DataNode] = [
        DataNode(
            id: "category",
            title: "category",
            systemImage: "folder",
            children: [
                DataNode(
                    id: "film",
                    title: "film",
                    systemImage: "film",
                    children: [
                        DataNode(
                            id: "actor",
                            title: "actor",
                            systemImage: "person.2",
                            children: nil
                        )
                    ]
                )
            ]
        )
    ]
}
