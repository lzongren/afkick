import CoreMediaIO
import Foundation
import AFKickCore

/// Thin CoreMediaIO wrapper: camera enumeration and stream-state observation.
///
/// Uses `kCMIODevicePropertyDeviceIsRunningSomewhere`, which fires for external
/// UVC cameras (AVFoundation's `isInUseByAnotherApplication` KVO does not).
enum CMIOCameraMonitor {
    static var runningAddress = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))

    static func devices() -> [(id: CMIOObjectID, info: CameraInfo)] {
        var addr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, &size) == 0 else { return [] }
        let count = Int(size) / MemoryLayout<CMIOObjectID>.size
        var ids = [CMIOObjectID](repeating: 0, count: count)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, size, &used, &ids) == 0
        else { return [] }
        return ids.map { id in
            (id, CameraInfo(
                name: stringProperty(id, kCMIOObjectPropertyName) ?? "",
                uniqueID: stringProperty(id, kCMIODevicePropertyDeviceUID) ?? ""))
        }
    }

    static func isRunningSomewhere(_ id: CMIOObjectID) -> Bool {
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(id, &runningAddress, 0, nil, &size) == 0
        else { return false }
        var used: UInt32 = 0
        var val: UInt32 = 0
        guard CMIOObjectGetPropertyData(id, &runningAddress, 0, nil, size, &used, &val) == 0
        else { return false }
        return val != 0
    }

    /// Invokes `onChange` on the main queue whenever the device's
    /// running-somewhere state may have changed.
    static func observeRunningState(
        of id: CMIOObjectID, onChange: @escaping () -> Void
    ) -> Bool {
        CMIOObjectAddPropertyListenerBlock(id, &runningAddress, DispatchQueue.main) { _, _ in
            onChange()
        } == 0
    }

    private static func stringProperty(
        _ id: CMIOObjectID, _ selector: Int
    ) -> String? {
        var addr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(selector),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == 0 else { return nil }
        var used: UInt32 = 0
        var cfStr: Unmanaged<CFString>?
        guard CMIOObjectGetPropertyData(id, &addr, 0, nil, size, &used, &cfStr) == 0
        else { return nil }
        return cfStr?.takeRetainedValue() as String?
    }
}
