import ArgumentParser
import Subprocess

@main
struct configulator: AsyncParsableCommand {
	mutating func run() async throws {
		let result = try await Subprocess.run(.name("ls"))
		print(result.processIdentifier)
		print(result.terminationStatus)
		print(result.standardOutput!)
	}
}
