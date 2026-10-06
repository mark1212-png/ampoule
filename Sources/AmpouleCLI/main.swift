import AmpouleCore
import Foundation

let usage = """
    usage: ampoule --version
           ampoule validate <config.json>
    """

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "--version":
    print("ampoule \(Ampoule.version)")
case "validate":
    guard arguments.count == 2 else { fail(usage) }
    let url = URL(fileURLWithPath: arguments[1])
    do {
        let configuration = try VMConfiguration.decode(from: Data(contentsOf: url))
        print("ok: \(configuration.name) (\(configuration.guestOS.rawValue))")
    } catch {
        fail("invalid: \(error)")
    }
default:
    fail(usage)
}
