import Foundation
import Testing
@testable import MuxyProtocol

@Suite("Workspace tree helpers")
struct WorkspaceTreeTests {
    private func makeArea(id: String, tabIDs: [String] = [], active: String? = nil) -> TabArea {
        let tabs = tabIDs.map {
            Tab(id: $0, kind: .terminal, title: $0, isPinned: false, paneID: "pane-\($0)")
        }
        return TabArea(id: id, projectPath: "/x", tabs: tabs, activeTabID: active)
    }

    @Test("findArea returns the area when present at any depth")
    func findAreaFindsNested() {
        let leftLeft = SplitNode.tabArea(makeArea(id: "a1"))
        let leftRight = SplitNode.tabArea(makeArea(id: "a2"))
        let left = SplitNode.split(Split(direction: .horizontal, first: leftLeft, second: leftRight))
        let right = SplitNode.tabArea(makeArea(id: "a3"))
        let root = SplitNode.split(Split(direction: .vertical, first: left, second: right))

        #expect(root.findArea(id: "a2")?.id == "a2")
        #expect(root.findArea(id: "a3")?.id == "a3")
        #expect(root.findArea(id: "missing") == nil)
    }

    @Test("flattenAreas enumerates every tab area in tree order")
    func flattenAreasInOrder() {
        let a1 = SplitNode.tabArea(makeArea(id: "a1"))
        let a2 = SplitNode.tabArea(makeArea(id: "a2"))
        let a3 = SplitNode.tabArea(makeArea(id: "a3"))
        let left = SplitNode.split(Split(direction: .horizontal, first: a1, second: a2))
        let root = SplitNode.split(Split(direction: .vertical, first: left, second: a3))

        #expect(root.flattenAreas().map(\.id) == ["a1", "a2", "a3"])
    }

    @Test("Workspace.focusedArea reads through to the focused tab area")
    func focusedAreaResolves() {
        let area = makeArea(id: "focused", tabIDs: ["t1"], active: "t1")
        let workspace = Workspace(
            projectID: "p1",
            worktreeID: "w1",
            focusedAreaID: "focused",
            root: .tabArea(area)
        )
        #expect(workspace.focusedArea?.id == "focused")
        #expect(workspace.focusedArea?.activeTabID == "t1")
    }

    @Test("Workspace.focusedArea is nil when focusedAreaID is stale")
    func focusedAreaMissing() {
        let area = makeArea(id: "other")
        let workspace = Workspace(
            projectID: "p1",
            worktreeID: "w1",
            focusedAreaID: "missing",
            root: .tabArea(area)
        )
        #expect(workspace.focusedArea == nil)
    }
}
