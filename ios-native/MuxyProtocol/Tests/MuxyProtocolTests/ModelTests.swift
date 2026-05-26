import Foundation
import Testing
@testable import MuxyProtocol

@Suite("Model JSON round-trips")
struct ModelTests {
    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    @Test("Project decodes with optional fields absent")
    func projectDecodesMinimal() throws {
        let json = """
        {
          "id": "p1",
          "name": "Muxy",
          "path": "/Users/x/muxy",
          "sortOrder": 0,
          "createdAt": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let project = try JSONDecoder().decode(Project.self, from: json)
        #expect(project.id == "p1")
        #expect(project.icon == nil)
        #expect(project.logo == nil)
        #expect(project.iconColor == nil)
    }

    @Test("Project round-trips with all fields")
    func projectRoundTrip() throws {
        let project = Project(
            id: "p1",
            name: "Muxy",
            path: "/x",
            sortOrder: 1,
            createdAt: "2026-01-01T00:00:00Z",
            icon: "terminal",
            logo: "data:image/png;base64,",
            iconColor: "#FF0000"
        )
        let decoded = try roundTrip(project)
        #expect(decoded == project)
    }

    @Test("Workspace tree decodes nested splits and tab areas")
    func workspaceTreeDecodes() throws {
        let json = """
        {
          "projectID": "p1",
          "worktreeID": "w1",
          "focusedAreaID": "a1",
          "root": {
            "type": "split",
            "split": {
              "direction": "horizontal",
              "first": {
                "type": "tabArea",
                "tabArea": {
                  "id": "a1",
                  "projectPath": "/x",
                  "tabs": [
                    { "id": "t1", "kind": "terminal", "title": "zsh", "isPinned": false, "paneID": "pane-1" }
                  ],
                  "activeTabID": "t1"
                }
              },
              "second": {
                "type": "tabArea",
                "tabArea": {
                  "id": "a2",
                  "projectPath": "/x",
                  "tabs": [],
                  "activeTabID": null
                }
              }
            }
          }
        }
        """.data(using: .utf8)!

        let workspace = try JSONDecoder().decode(Workspace.self, from: json)
        #expect(workspace.focusedAreaID == "a1")
        guard case .split(let split) = workspace.root else {
            Issue.record("Expected split root")
            return
        }
        #expect(split.direction == .horizontal)
        guard case .tabArea(let firstArea) = split.first else {
            Issue.record("Expected first to be a tab area")
            return
        }
        #expect(firstArea.tabs.first?.kind == .terminal)
        #expect(firstArea.tabs.first?.paneID == "pane-1")
    }

    @Test("Workspace tree round-trips")
    func workspaceTreeRoundTrip() throws {
        let area = TabArea(
            id: "a1",
            projectPath: "/x",
            tabs: [
                Tab(id: "t1", kind: .terminal, title: "zsh", isPinned: false, paneID: "pane-1")
            ],
            activeTabID: "t1"
        )
        let workspace = Workspace(
            projectID: "p1",
            worktreeID: "w1",
            focusedAreaID: "a1",
            root: .tabArea(area)
        )
        let decoded = try roundTrip(workspace)
        #expect(decoded == workspace)
    }

    @Test("Tab decodes without paneID for non-terminal kinds")
    func tabDecodesWithoutPaneID() throws {
        let json = """
        { "id": "t1", "kind": "vcs", "title": "Git", "isPinned": false }
        """.data(using: .utf8)!
        let tab = try JSONDecoder().decode(Tab.self, from: json)
        #expect(tab.kind == .vcs)
        #expect(tab.paneID == nil)
    }

    @Test("TerminalOutput round-trips")
    func terminalOutputRoundTrip() throws {
        let output = TerminalOutput(paneID: "pane-1", bytes: "QUJD")
        let decoded = try roundTrip(output)
        #expect(decoded == output)
    }

    @Test("TerminalSnapshot round-trips")
    func terminalSnapshotRoundTrip() throws {
        let snap = TerminalSnapshot(paneID: "pane-1", bytes: "QUJD")
        let decoded = try roundTrip(snap)
        #expect(decoded == snap)
    }

    @Test("PaneOwnership decodes mac and remote variants")
    func paneOwnershipDecodes() throws {
        let macJSON = """
        { "paneID": "p1", "owner": { "mac": { "deviceName": "Saeed's Mac" } } }
        """.data(using: .utf8)!
        let macOwn = try JSONDecoder().decode(PaneOwnership.self, from: macJSON)
        #expect(macOwn.owner == .mac(deviceName: "Saeed's Mac"))

        let remoteJSON = """
        { "paneID": "p1", "owner": { "remote": { "deviceID": "d1", "deviceName": "iPhone" } } }
        """.data(using: .utf8)!
        let remoteOwn = try JSONDecoder().decode(PaneOwnership.self, from: remoteJSON)
        #expect(remoteOwn.owner == .remote(deviceID: "d1", deviceName: "iPhone"))
    }

    @Test("PaneOwnership round-trips")
    func paneOwnershipRoundTrip() throws {
        let mac = PaneOwnership(paneID: "p1", owner: .mac(deviceName: "Mac"))
        let remote = PaneOwnership(paneID: "p2", owner: .remote(deviceID: "d1", deviceName: "iPhone"))
        #expect(try roundTrip(mac) == mac)
        #expect(try roundTrip(remote) == remote)
    }

    @Test("VCSStatus decodes with optional fields")
    func vcsStatusDecodes() throws {
        let json = """
        {
          "branch": "main",
          "aheadCount": 0,
          "behindCount": 0,
          "hasUpstream": true,
          "stagedFiles": [
            { "path": "a.txt", "status": "modified", "isUntracked": false }
          ],
          "changedFiles": [
            { "path": "b.txt", "status": "untracked", "isUntracked": true }
          ],
          "defaultBranch": "main",
          "pullRequest": {
            "url": "https://github.com/x/y/pull/1",
            "number": 1,
            "state": "OPEN",
            "isDraft": false,
            "baseBranch": "main",
            "mergeable": true,
            "mergeStateStatus": "CLEAN",
            "checks": { "status": "success", "passing": 3, "failing": 0, "pending": 0, "total": 3 }
          }
        }
        """.data(using: .utf8)!

        let status = try JSONDecoder().decode(VCSStatus.self, from: json)
        #expect(status.branch == "main")
        #expect(status.stagedFiles.first?.status == .modified)
        #expect(status.pullRequest?.mergeStateStatus == .clean)
        #expect(status.pullRequest?.checks?.status == .success)
    }
}
