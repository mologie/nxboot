import Foundation
import Sentry

@MainActor
@Observable
class Sentry {
    static let enableByDefault = true

    var allowCrashReports: Bool {
        didSet { Task { @MainActor in commit() } }
    }
    var allowUsagePings: Bool {
        didSet { Task { @MainActor in commit() } }
    }

    private var active = false

    init() {
        // explicitly fetch preferences, because @AppStorage is unavailable during init
        allowCrashReports = Sentry.appStorageBool(forKey: "NXBootAllowCrashReports") ?? Sentry.enableByDefault
        allowUsagePings = Sentry.appStorageBool(forKey: "NXBootAllowUsagePings") ?? Sentry.enableByDefault
        commit()
    }

    private func commit() {
#if DEBUG
        print("Sentry integration: Disabled in debug build")
#else
        if active {
            SentrySDK.close()
            active = false
        }
        if allowCrashReports || allowUsagePings {
            SentrySDK.start { options in
                options.dsn = "https://6f191f8afd06257e9b2c2cdd7977cd1e@o4506496566231040.ingest.sentry.io/4506496570032128"
                options.enableAppHangTracking = false
                options.enableAutoSessionTracking = self.allowUsagePings
                options.enableCrashHandler = self.allowCrashReports
                options.enableMetricKit = true
                options.enableTimeToFullDisplayTracing = true
                options.enableWatchdogTerminationTracking = false
                options.swiftAsyncStacktraces = true
#if DEBUG
                options.debug = true
#endif
            }
            active = true
            print("Sentry integration: Enabled with crashes=\(allowCrashReports) usage=\(allowUsagePings)")
        } else {
            print("Sentry integration: Disabled")
        }
#endif
    }

    func usagePing(error: Error?) {
        if !active || !allowUsagePings {
            return
        }
        var level: SentryLevel
        var message: String
        if let error {
            level = .warning
            message = "Boot failed"
            if let bootError = error as? Device.BootError {
                message += ": \(bootError.message)"
            }
        } else {
            level = .info
            message = "Boot successful"
        }
        let event = Event(level: level)
        event.message = SentryMessage(formatted: message)
        SentrySDK.capture(event: event)
    }

    private static func appStorageBool(forKey: String) -> Bool? {
        // like UserDefaults.standard.bool, but with optional result when key is absent
        let number = UserDefaults.standard.object(forKey: forKey) as? NSNumber
        return number?.boolValue
    }
}
