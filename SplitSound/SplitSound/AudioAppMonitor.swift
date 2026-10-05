//
//  AudioOutputMonitor.swift
//  SplitSound
//
import Foundation

final class AudioAppMonitor: @unchecked Sendable {

    // MARK: - Queue

    private let monitorQueue = DispatchQueue(
        label: "com.shivam.SplitSound.app-monitor",
        qos: .utility
    )

    // MARK: - State

    private var timer: DispatchSourceTimer?
    private var isMonitoring = false

    private var previousApps: [String: AudioAppInfo] = [:]

    private var onAppsChanged: (([AudioAppInfo]) -> Void)?

    // MARK: - Start

    func start(
        onAppsChanged: @escaping ([AudioAppInfo]) -> Void
    ) {
        monitorQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isMonitoring else { return }

            self.onAppsChanged = onAppsChanged

            // Get the initial list of applications producing audio.
            let initialApps =
                (try? AudioProcessManager.audibleApps()) ?? []

            self.previousApps = Dictionary(
                uniqueKeysWithValues: initialApps.map {
                    ($0.id, $0)
                }
            )

            // Poll every 500 ms.
            let timer = DispatchSource.makeTimerSource(
                queue: self.monitorQueue
            )

            timer.schedule(
                deadline: .now() + .milliseconds(500),
                repeating: .milliseconds(500),
                leeway: .milliseconds(100)
            )

            timer.setEventHandler { [weak self] in
                self?.checkApplications()
            }

            self.timer = timer
            self.isMonitoring = true

            timer.resume()

            print("✅ AudioAppMonitor started")
            print("📱 Initial audible apps: \(initialApps.count)")

            for app in initialApps {
                print("   • \(app.name)")
            }
        }
    }

    // MARK: - Check Applications

    private func checkApplications() {
        guard isMonitoring else {
            return
        }

        // Get the current applications that are producing audio.
        let currentApps =
            (try? AudioProcessManager.audibleApps()) ?? []

        let currentDictionary = Dictionary(
            uniqueKeysWithValues: currentApps.map {
                ($0.id, $0)
            }
        )

        let oldIDs = Set(previousApps.keys)
        let newIDs = Set(currentDictionary.keys)

        let started = newIDs.subtracting(oldIDs)
        let stopped = oldIDs.subtracting(newIDs)

        var changed = !started.isEmpty || !stopped.isEmpty

        // Detect changes in process IDs / process object IDs.
        //
        // This handles cases where the same application is still present
        // but its underlying audio process objects changed.
        if !changed {
            for appID in newIDs {

                guard
                    let oldApp = previousApps[appID],
                    let newApp = currentDictionary[appID]
                else {
                    changed = true
                    break
                }

                if oldApp.processIDs != newApp.processIDs ||
                   oldApp.processObjectIDs != newApp.processObjectIDs {

                    changed = true
                    break
                }
            }
        }

        // Nothing changed.
        if !changed {
            previousApps = currentDictionary
            return
        }

        // MARK: - Logging

        print("========================================")
        print("🔄 AUDIO APPLICATION SET CHANGED")

        if !started.isEmpty {
            print("🟢 Started:")

            for appID in started {
                if let app = currentDictionary[appID] {
                    print("   • \(app.name)")
                    print("     ID: \(app.id)")
                    print("     Bundle: \(app.bundleID ?? "nil")")
                    print("     Processes: \(app.processIDs)")
                    print("     Objects: \(app.processObjectIDs)")
                }
            }
        }

        if !stopped.isEmpty {
            print("🔴 Stopped:")

            for appID in stopped {
                if let app = previousApps[appID] {
                    print("   • \(app.name)")
                    print("     ID: \(app.id)")
                    print("     Bundle: \(app.bundleID ?? "nil")")
                }
            }
        }

        print("📱 Current audible apps:")

        for app in currentApps {
            print("   • \(app.name)")
        }

        print("========================================")

        // Save the new state.
        previousApps = currentDictionary

        // Tell AudioEngineController to rebuild the audio graph.
        onAppsChanged?(currentApps)
    }

    // MARK: - Stop

    func stop() {
        monitorQueue.async { [weak self] in
            guard let self = self else { return }

            guard self.isMonitoring else {
                return
            }

            self.isMonitoring = false

            self.timer?.setEventHandler {}
            self.timer?.cancel()
            self.timer = nil

            self.onAppsChanged = nil
            self.previousApps.removeAll()

            print("🛑 AudioAppMonitor stopped")
        }
    }
}
