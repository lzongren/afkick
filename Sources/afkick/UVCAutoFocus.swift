import Foundation
import UVCKit
import AFKickCore

/// Toggles the UVC auto-focus control off/on via the vendored UVCKit classes.
enum UVCAutoFocus {
    /// Finds the UVC device whose name or location matches the camera, then
    /// toggles CT_FOCUS_AUTO_CONTROL false -> true to restart the AF scan.
    static func kick(cameraName: String) -> Bool {
        guard let controllers = UVCController.uvcControllers() as? [UVCController] else {
            return false
        }
        let matcher = CameraMatcher(pattern: cameraName)
        let infos = controllers.map {
            CameraInfo(name: $0.deviceName() ?? "", uniqueID: String(format: "0x%08x", $0.locationId()))
        }
        guard let match = matcher.firstMatch(in: infos),
              let controller = controllers.first(where: { ($0.deviceName() ?? "") == match.name })
        else { return false }

        guard let control = controller.control(withName: "auto-focus") else { return false }
        let noFlags = UVCTypeScanFlags(rawValue: 0)
        guard control.setCurrentValueFromCString("false", flags: noFlags) else { return false }
        usleep(300_000)
        return control.setCurrentValueFromCString("true", flags: noFlags)
    }
}
