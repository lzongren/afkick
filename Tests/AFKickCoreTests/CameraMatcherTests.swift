import Testing
@testable import AFKickCore

@Suite("CameraMatcher")
struct CameraMatcherTests {
    let cameras = [
        CameraInfo(name: "FaceTime HD Camera", uniqueID: "1FD4B3A2"),
        CameraInfo(name: "Dell U3223QZ Webcam", uniqueID: "0x2234200413cc024"),
        CameraInfo(name: "Insta360 Virtual Camera", uniqueID: "4BA85DDE"),
    ]

    @Test("substring match, case-insensitive")
    func substringMatch() {
        let m = CameraMatcher(pattern: "dell")
        #expect(m.firstMatch(in: cameras)?.name == "Dell U3223QZ Webcam")
    }

    @Test("exact name match")
    func exactMatch() {
        let m = CameraMatcher(pattern: "Dell U3223QZ Webcam")
        #expect(m.firstMatch(in: cameras)?.name == "Dell U3223QZ Webcam")
    }

    @Test("no match returns nil")
    func noMatch() {
        let m = CameraMatcher(pattern: "logitech")
        #expect(m.firstMatch(in: cameras) == nil)
    }

    @Test("empty pattern matches nothing")
    func emptyPattern() {
        let m = CameraMatcher(pattern: "")
        #expect(m.firstMatch(in: cameras) == nil)
    }

    @Test("match by unique ID")
    func uniqueIDMatch() {
        let m = CameraMatcher(pattern: "413cc024")
        #expect(m.firstMatch(in: cameras)?.name == "Dell U3223QZ Webcam")
    }
}
