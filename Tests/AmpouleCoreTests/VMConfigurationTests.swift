import AmpouleCore
import Foundation
import Testing

private func makeConfiguration() -> VMConfiguration {
    VMConfiguration(name: "Ubuntu", guestOS: .linux, cpuCount: 4, memoryMiB: 4096, disks: [DiskConfiguration(path: "disk.img")])
}

@Test func validConfigurationPasses() throws {
    try makeConfiguration().validate()
}

@Test func roundTripsThroughJSON() throws {
    let configuration = makeConfiguration()
    let data = try JSONEncoder().encode(configuration)
    #expect(try VMConfiguration.decode(from: data) == configuration)
}

@Test func rejectsUnknownSchemaVersion() {
    var configuration = makeConfiguration()
    configuration.schemaVersion = 2
    #expect(throws: ConfigurationError.unsupportedSchemaVersion(2)) { try configuration.validate() }
}

@Test func rejectsBlankName() {
    var configuration = makeConfiguration()
    configuration.name = "  "
    #expect(throws: ConfigurationError.emptyName) { try configuration.validate() }
}

@Test(arguments: [0, 65])
func rejectsCPUCountOutOfRange(count: Int) {
    var configuration = makeConfiguration()
    configuration.cpuCount = count
    #expect(throws: ConfigurationError.cpuCountOutOfRange(count)) { try configuration.validate() }
}

@Test func rejectsTooLittleMemory() {
    var configuration = makeConfiguration()
    configuration.memoryMiB = 256
    #expect(throws: ConfigurationError.memoryTooSmall(256)) { try configuration.validate() }
}

@Test func rejectsNoDisks() {
    var configuration = makeConfiguration()
    configuration.disks = []
    #expect(throws: ConfigurationError.noDisks) { try configuration.validate() }
}

@Test(arguments: ["", "/etc/disk.img", "../disk.img", "disks/../../disk.img"])
func rejectsDiskPathsOutsideBundle(path: String) {
    var configuration = makeConfiguration()
    configuration.disks = [DiskConfiguration(path: path)]
    #expect(throws: ConfigurationError.diskPathOutsideBundle(path)) { try configuration.validate() }
}

@Test func rejectsUnknownGuestOS() {
    let json = #"{"schemaVersion":1,"name":"x","guestOS":"beos","cpuCount":1,"memoryMiB":1024,"disks":[{"path":"d.img","readOnly":false}]}"#
    #expect(throws: DecodingError.self) { try VMConfiguration.decode(from: Data(json.utf8)) }
}

@Test func configWithoutSharedFoldersDecodesAsNone() throws {
    let json = #"{"schemaVersion":1,"name":"x","guestOS":"linux","cpuCount":1,"memoryMiB":1024,"disks":[{"path":"d.img","readOnly":false}]}"#
    #expect(try VMConfiguration.decode(from: Data(json.utf8)).sharedFolders.isEmpty)
}

@Test func sharedFoldersRoundTrip() throws {
    var configuration = makeConfiguration()
    configuration.sharedFolders = [SharedFolder(path: "/Users/me/Projects"), SharedFolder(path: "/Users/me/Notes", readOnly: true)]
    let data = try JSONEncoder().encode(configuration)
    #expect(try VMConfiguration.decode(from: data) == configuration)
}

@Test(arguments: ["relative/path", "", "/"])
func rejectsSharedFolderPathsThatArentAbsoluteFolders(path: String) {
    var configuration = makeConfiguration()
    configuration.sharedFolders = [SharedFolder(path: path)]
    #expect(throws: ConfigurationError.sharedFolderPathNotAbsolute(path)) { try configuration.validate() }
}

@Test func rejectsSharedFoldersWithTheSameName() {
    var configuration = makeConfiguration()
    configuration.sharedFolders = [SharedFolder(path: "/Users/a/Projects"), SharedFolder(path: "/Volumes/Work/Projects")]
    #expect(throws: ConfigurationError.duplicateSharedFolderName("Projects")) { try configuration.validate() }
}
