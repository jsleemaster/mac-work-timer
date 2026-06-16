import Foundation
import MacWorkTimerCore

struct SystemActivityStartProvider {
    let clock: WorkdayClock

    func preferredStart(for now: Date) -> Date? {
        guard let log = pmsetLog() else {
            return nil
        }

        return SystemActivityLogParser.firstUserActivity(in: log, workDate: clock.workDate(for: now))
    }

    private func pmsetLog() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "log"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
