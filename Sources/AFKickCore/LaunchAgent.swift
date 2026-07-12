import Foundation

/// Renders and locates the launchd agent that keeps `afkick watch` running.
public enum LaunchAgent {
    public static let label = "io.github.lzongren.afkick"

    public static func plistPath(home: String) -> String {
        "\(home)/Library/LaunchAgents/\(label).plist"
    }

    public static func plist(
        executable: String, arguments: [String], logPath: String
    ) -> String {
        let dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable] + arguments,
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": logPath,
            "StandardErrorPath": logPath,
        ]
        let data = try! PropertyListSerialization.data(
            fromPropertyList: dict, format: .xml, options: 0)
        return String(data: data, encoding: .utf8)!
    }
}
