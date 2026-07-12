/// A camera as seen by the host, decoupled from CoreMediaIO for testability.
public struct CameraInfo: Equatable {
    public let name: String
    public let uniqueID: String

    public init(name: String, uniqueID: String) {
        self.name = name
        self.uniqueID = uniqueID
    }
}

/// Case-insensitive substring matching over camera name or unique ID.
public struct CameraMatcher {
    private let pattern: String

    public init(pattern: String) {
        self.pattern = pattern.lowercased()
    }

    public func firstMatch(in cameras: [CameraInfo]) -> CameraInfo? {
        guard !pattern.isEmpty else { return nil }
        return cameras.first {
            $0.name.lowercased().contains(pattern)
                || $0.uniqueID.lowercased().contains(pattern)
        }
    }
}
