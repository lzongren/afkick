import Testing
import Foundation
@testable import AFKickCore

@Suite("LaunchAgent")
struct LaunchAgentTests {
    @Test("renders a valid plist with the executable path and camera pattern")
    func rendersPlist() throws {
        let xml = LaunchAgent.plist(
            executable: "/usr/local/bin/afkick",
            arguments: ["watch", "--camera", "Dell"],
            logPath: "/tmp/afkick.log"
        )
        let parsed = try PropertyListSerialization.propertyList(
            from: xml.data(using: .utf8)!, options: [], format: nil) as! [String: Any]

        #expect(parsed["Label"] as? String == LaunchAgent.label)
        let args = parsed["ProgramArguments"] as! [String]
        #expect(args == ["/usr/local/bin/afkick", "watch", "--camera", "Dell"])
        #expect(parsed["RunAtLoad"] as? Bool == true)
        #expect(parsed["KeepAlive"] as? Bool == true)
        #expect(parsed["StandardErrorPath"] as? String == "/tmp/afkick.log")
    }

    @Test("plist path lives in user LaunchAgents")
    func plistPath() {
        let path = LaunchAgent.plistPath(home: "/Users/alice")
        #expect(path == "/Users/alice/Library/LaunchAgents/\(LaunchAgent.label).plist")
    }

    @Test("camera pattern with special XML characters is escaped")
    func xmlEscaping() throws {
        let xml = LaunchAgent.plist(
            executable: "/usr/local/bin/afkick",
            arguments: ["watch", "--camera", "A <&> Camera"],
            logPath: "/tmp/afkick.log"
        )
        let parsed = try PropertyListSerialization.propertyList(
            from: xml.data(using: .utf8)!, options: [], format: nil) as! [String: Any]
        let args = parsed["ProgramArguments"] as! [String]
        #expect(args.last == "A <&> Camera")
    }
}
