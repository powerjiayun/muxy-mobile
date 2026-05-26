import Foundation

extension SplitNode {
    public func findArea(id: String) -> TabArea? {
        switch self {
        case .tabArea(let area):
            return area.id == id ? area : nil
        case .split(let split):
            return split.first.findArea(id: id) ?? split.second.findArea(id: id)
        }
    }

    public func flattenAreas() -> [TabArea] {
        switch self {
        case .tabArea(let area):
            return [area]
        case .split(let split):
            return split.first.flattenAreas() + split.second.flattenAreas()
        }
    }
}

extension Workspace {
    public var focusedArea: TabArea? {
        root.findArea(id: focusedAreaID)
    }

    public var allAreas: [TabArea] {
        root.flattenAreas()
    }
}
