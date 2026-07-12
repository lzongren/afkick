import ArgumentParser
import Foundation
import AFKickCore

@main
struct AFKick: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "afkick",
        abstract: "Kick a UVC webcam's autofocus when a video stream starts.",
        discussion: """
            Some external webcams (e.g. the one built into the Dell U3223QZ \
            monitor) report autofocus as enabled but never run the focus scan \
            when an app opens the stream — the image stays blurry until \
            vendor software pokes the camera. afkick watches for stream \
            starts and toggles the UVC auto-focus control to wake the lens.
            """,
        version: "1.0.0",
        subcommands: [Watch.self, Kick.self, List.self, Install.self, Uninstall.self],
        defaultSubcommand: Watch.self
    )
}

struct CameraOptions: ParsableArguments {
    @Option(name: [.short, .long], help: "Camera name substring to match (case-insensitive).")
    var camera: String = "Dell"
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List cameras and their streaming state.")

    func run() throws {
        for (id, info) in CMIOCameraMonitor.devices() {
            let running = CMIOCameraMonitor.isRunningSomewhere(id) ? "streaming" : "idle"
            print("\(info.name) [\(info.uniqueID)] — \(running)")
        }
    }
}

struct Kick: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Toggle autofocus once, right now.")

    @OptionGroup var options: CameraOptions

    func run() throws {
        guard UVCAutoFocus.kick(cameraName: options.camera) else {
            throw ValidationError("no UVC camera matching \"\(options.camera)\" or control write failed")
        }
        print("autofocus kicked")
    }
}

struct Watch: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Watch for stream starts and kick autofocus automatically.")

    @OptionGroup var options: CameraOptions

    @Option(help: "Seconds to wait after stream start before kicking.")
    var delay: Double = 1.5

    @Option(help: "Minimum seconds between kicks.")
    var debounce: Double = 3.0

    func run() throws {
        let matcher = CameraMatcher(pattern: options.camera)
        let devices = CMIOCameraMonitor.devices()
        guard let (deviceID, info) = devices.first(where: { matcher.firstMatch(in: [$0.info]) != nil })
        else {
            throw ValidationError(
                "no camera matching \"\(options.camera)\"; available: "
                    + devices.map(\.info.name).joined(separator: ", "))
        }

        log("watching \(info.name) [\(info.uniqueID)]")

        var policy = KickPolicy(delay: delay, debounce: debounce)
        let cameraName = options.camera

        func act(on action: KickPolicy.Action) {
            guard case .kick(let at) = action else { return }
            let wait = max(0, at - Date().timeIntervalSince1970)
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
                // separate copy check: skip if the stream already stopped
                guard policy.shouldFire(at: Date().timeIntervalSince1970) else {
                    log("stream stopped before kick — skipped")
                    return
                }
                if UVCAutoFocus.kick(cameraName: cameraName) {
                    log("autofocus kicked")
                } else {
                    log("kick failed — camera unplugged or control rejected")
                }
            }
            log("stream started — kicking in \(String(format: "%.1f", wait))s")
        }

        act(on: policy.observe(
            isRunning: CMIOCameraMonitor.isRunningSomewhere(deviceID),
            at: Date().timeIntervalSince1970,
            isFirstObservation: true))

        guard CMIOCameraMonitor.observeRunningState(of: deviceID, onChange: {
            act(on: policy.observe(
                isRunning: CMIOCameraMonitor.isRunningSomewhere(deviceID),
                at: Date().timeIntervalSince1970))
        }) else {
            throw ValidationError("failed to register CoreMediaIO listener")
        }

        RunLoop.main.run()
    }
}

struct Install: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Install a launchd agent so afkick watch runs at login.")

    @OptionGroup var options: CameraOptions

    func run() throws {
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let logPath = (home as NSString).appendingPathComponent("Library/Logs/afkick.log")
        let plist = LaunchAgent.plist(
            executable: exe,
            arguments: ["watch", "--camera", options.camera],
            logPath: logPath)
        let path = LaunchAgent.plistPath(home: home)
        try plist.write(toFile: path, atomically: true, encoding: .utf8)
        shell("launchctl", "unload", path)
        shell("launchctl", "load", path)
        print("installed \(path)")
        print("logs: \(logPath)")
    }
}

struct Uninstall: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove the launchd agent.")

    func run() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = LaunchAgent.plistPath(home: home)
        shell("launchctl", "unload", path)
        try? FileManager.default.removeItem(atPath: path)
        print("uninstalled \(path)")
    }
}

func log(_ msg: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    FileHandle.standardError.write("\(ts) \(msg)\n".data(using: .utf8)!)
}

@discardableResult
func shell(_ args: String...) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = args
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    try? p.run()
    p.waitUntilExit()
    return p.terminationStatus
}
