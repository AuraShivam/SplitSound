import Foundation

final class AudioEngineController: @unchecked Sendable {

    // MARK: - Shared Instance

    static let shared =
        AudioEngineController()

    // MARK: - Queue

    private let audioQueue =
        DispatchQueue(
            label:
                "com.shivam.SplitSound.audio",
            qos:
                .userInitiated
        )

    // MARK: - Managers

    private var tapManager:
        AudioTapManager?

    private var aggregateManager:
        AudioAggregateManager?

    private var appMonitor:
        AudioAppMonitor?

    private var outputMonitor:
        AudioOutputMonitor?

    // MARK: - State

    private var isStarted =
        false

    private var currentOutputUID:
        String?

    private var currentApplications:
        [AudioAppInfo] = []

    // Stores application volume independently
    // from the currently running audio graph.
    private var appGains:
        [String: Float] = [:]

    // MARK: - Init

    private init() {}

    // MARK: - Start

    func start() {

        audioQueue.async { [weak self] in

            guard let self else {
                return
            }

            guard !self.isStarted else {
                return
            }

            self.isStarted = true

            self.startAudioEngine()
        }
    }

    // MARK: - Start Audio Engine

    private func startAudioEngine() {

        print("")
        print("========== SPLITSOUND START ==========")
        print("")

        // -----------------------------------------
        // Create managers.
        // -----------------------------------------

        let tapManager =
            AudioTapManager()

        let aggregateManager =
            AudioAggregateManager()

        let appMonitor =
            AudioAppMonitor()

        let outputMonitor =
            AudioOutputMonitor()

        self.tapManager =
            tapManager

        self.aggregateManager =
            aggregateManager

        self.appMonitor =
            appMonitor

        self.outputMonitor =
            outputMonitor

        // -----------------------------------------
        // Discover current default output.
        // -----------------------------------------

        guard let outputUID =
                AudioAggregateManager.defaultOutputDeviceUID()
        else {

            print(
                "❌ Could not determine default output device."
            )

            // Keep application monitoring alive so that
            // the engine can be started later when an
            // output becomes available.
            appMonitor.start { [weak self] applications in

                guard let self else {
                    return
                }

                self.audioQueue.async {

                    guard self.isStarted else {
                        return
                    }

                    guard let outputUID =
                            AudioAggregateManager
                                .defaultOutputDeviceUID()
                    else {
                        return
                    }

                    self.currentOutputUID =
                        outputUID

                    self.handleAudioApplicationsChanged(
                        applications
                    )
                }
            }

            return
        }

        self.currentOutputUID =
            outputUID

        print(
            "🔊 Current output UID:",
            outputUID
        )

        // -----------------------------------------
        // Start application monitor.
        // -----------------------------------------

        appMonitor.start { [weak self] applications in

            guard let self else {
                return
            }

            self.audioQueue.async {

                guard self.isStarted else {
                    return
                }

                self.handleAudioApplicationsChanged(
                    applications
                )
            }
        }

        // -----------------------------------------
        // Start output monitor.
        // -----------------------------------------

        outputMonitor.start(
            initialOutputUID:
                outputUID
        ) { [weak self] newUID in

            guard let self else {
                return
            }

            self.audioQueue.async {

                guard self.isStarted else {
                    return
                }

                self.handleOutputDeviceChanged(
                    newUID
                )
            }
        }

        // -----------------------------------------
        // Discover currently active applications.
        // -----------------------------------------

        let applications:
            [AudioAppInfo]

        do {

            applications =
                try AudioProcessManager.audibleApps()

        } catch {

            print(
                "❌ Failed to discover audio applications:"
            )

            print(error)

            return
        }

        // -----------------------------------------
        // Save current applications.
        // -----------------------------------------

        self.currentApplications =
            applications

        // -----------------------------------------
        // Create default gain for new applications.
        // Existing application gains are preserved.
        // -----------------------------------------

        for app in applications {

            if self.appGains[app.id] == nil {

                self.appGains[app.id] =
                    0.50
            }
        }

        // -----------------------------------------
        // Print application information.
        // -----------------------------------------

        print("")
        print("========== ACTIVE AUDIO APPS ==========")

        print(
            "Count:",
            applications.count
        )

        for app in applications {

            print("🔊", app.name)

            print(
                "   Bundle:",
                app.bundleID ?? "Unknown"
            )

            print(
                "   Path:",
                app.appPath
            )

            print(
                "   PIDs:",
                app.processIDs
            )

            print(
                "   Process Objects:",
                app.processObjectIDs
            )

            print("")
        }

        print("========================================")
        print("")

        // -----------------------------------------
        // No active applications.
        // -----------------------------------------

        guard !applications.isEmpty else {

            print(
                "⚠️ No active audio applications right now."
            )

            print(
                "✅ Monitors remain active."
            )

            print("")

            return
        }

        // -----------------------------------------
        // Build the initial graph.
        // -----------------------------------------

        rebuildAudioGraph(
            applications:
                applications,

            outputUID:
                outputUID
        )
    }

    // MARK: - Rebuild Audio Graph

    private func rebuildAudioGraph(
        applications:
            [AudioAppInfo],

        outputUID:
            String
    ) {

        print("")
        print("========== REBUILD AUDIO GRAPH ==========")

        print(
            "Output UID:",
            outputUID
        )

        print(
            "Applications:",
            applications.count
        )

        // -----------------------------------------
        // Stop existing IO.
        // -----------------------------------------

        aggregateManager?
            .stopIO()

        // -----------------------------------------
        // Destroy existing aggregate.
        // -----------------------------------------

        aggregateManager?
            .destroyAggregate()

        // -----------------------------------------
        // Destroy existing taps.
        // -----------------------------------------

        tapManager?
            .removeAllTaps()

        // -----------------------------------------
        // Update state.
        // -----------------------------------------

        currentOutputUID =
            outputUID

        currentApplications =
            applications

        // -----------------------------------------
        // Preserve existing gains.
        // Initialize new apps to 50%.
        // -----------------------------------------

        for app in applications {

            if appGains[app.id] == nil {

                appGains[app.id] =
                    0.50
            }
        }

        // -----------------------------------------
        // No applications.
        // -----------------------------------------

        guard !applications.isEmpty else {

            print(
                "⚠️ No active audio applications."
            )

            print(
                "Waiting for next application..."
            )

            print(
                "=========================================="
            )

            print("")

            return
        }

        // -----------------------------------------
        // Create one tap per application.
        // -----------------------------------------

        var activeAppIDs:
            [String] = []

        print("")
        print("========== CREATING APP TAPS ==========")

        for app in applications {

            print("")
            print(
                "Application:",
                app.name
            )

            print(
                "App ID:",
                app.id
            )

            print(
                "Process Objects:",
                app.processObjectIDs
            )

            guard let tap =
                    tapManager?.createTap(
                        appID:
                            app.id,

                        processObjectIDs:
                            app.processObjectIDs,

                        outputDeviceUID:
                            outputUID
                    )
            else {

                print(
                    "⚠️ Failed to create tap for:",
                    app.name
                )

                continue
            }

            print(
                "✅ Tap created for:",
                app.name
            )

            activeAppIDs.append(
                app.id
            )
        }

        print("")
        print("========================================")
        print("")

        // -----------------------------------------
        // At least one tap must exist.
        // -----------------------------------------

        guard !activeAppIDs.isEmpty else {

            print(
                "❌ No application taps were created."
            )

            print("")

            return
        }

        // -----------------------------------------
        // Get tap UIDs in the SAME application order.
        // -----------------------------------------

        guard let tapManager else {

            print(
                "❌ Tap manager unavailable."
            )

            return
        }

        let tapUIDs =
            tapManager.tapUIDs(
                for:
                    activeAppIDs
            )

        // -----------------------------------------
        // Validate application/tap count.
        // -----------------------------------------

        guard
            tapUIDs.count ==
                activeAppIDs.count
        else {

            print(
                "❌ Tap UID count does not match application count."
            )

            print(
                "Applications:",
                activeAppIDs.count
            )

            print(
                "Taps:",
                tapUIDs.count
            )

            return
        }

        // -----------------------------------------
        // Print mapping before aggregate creation.
        // -----------------------------------------

        print("")
        print("========== APP / TAP MAPPING ==========")

        for index in
            0..<activeAppIDs.count
        {

            print(
                "\(index):",
                activeAppIDs[index],
                "→",
                tapUIDs[index]
            )
        }

        print(
            "======================================="
        )

        // -----------------------------------------
        // Create aggregate.
        // -----------------------------------------

        guard let aggregateManager else {

            print(
                "❌ Aggregate manager unavailable."
            )

            return
        }

        aggregateManager.createAggregate(
            tapUIDs:
                tapUIDs,

            outputDeviceUID:
                outputUID
        )

        // -----------------------------------------
        // Check aggregate.
        // -----------------------------------------

        aggregateManager
            .printAggregateStatus()

        // -----------------------------------------
        // Start realtime IO.
        // -----------------------------------------

        aggregateManager.startIO(
            appIDs:
                activeAppIDs,

            tapUIDs:
                tapUIDs
        )

        // -----------------------------------------
        // Restore saved application gains.
        // -----------------------------------------

        print("")
        print("========== RESTORING APP GAINS ==========")

        for appID in
            activeAppIDs
        {

            let gain =
                appGains[appID]
                ?? 0.50

            print(
                "🎚️",
                appID,
                "→",
                gain
            )

            aggregateManager.setAppGain(
                appID:
                    appID,

                gain:
                    gain
            )
        }

        print(
            "=========================================="
        )

        // -----------------------------------------
        // Final state.
        // -----------------------------------------

        currentApplications =
            applications.filter { app in

                activeAppIDs.contains(
                    app.id
                )
            }

        currentOutputUID =
            outputUID

        print("")
        print("✅ Audio graph rebuilt")

        print(
            "Output:",
            outputUID
        )

        print(
            "Applications:",
            activeAppIDs.count
        )

        print(
            "Taps:",
            tapUIDs.count
        )

        print(
            "========================================"
        )

        print("")
    }

    // MARK: - Application Changes

    private func handleAudioApplicationsChanged(
        _ applications:
            [AudioAppInfo]
    ) {

        guard isStarted else {
            return
        }

        print("")
        print("========== AUDIO APPLICATION CHANGE ==========")

        print(
            "Detected applications:",
            applications.count
        )

        for app in applications {

            print(
                "🔊",
                app.name,
                app.processObjectIDs
            )
        }

        // -----------------------------------------
        // Re-check output device before rebuilding.
        // -----------------------------------------

        guard let outputUID =
                AudioAggregateManager.defaultOutputDeviceUID()
        else {

            print(
                "❌ No default output device available."
            )

            print("")

            return
        }

        // -----------------------------------------
        // Skip unnecessary rebuild if the callback
        // only contains the same graph state.
        // -----------------------------------------

        let currentIDs =
            Set(
                currentApplications.map {
                    $0.id
                }
            )

        let newIDs =
            Set(
                applications.map {
                    $0.id
                }
            )

        if currentIDs == newIDs,
           currentOutputUID == outputUID {

            var processObjectsChanged =
                false

            for app in applications {

                guard let oldApp =
                        currentApplications.first(
                            where: {
                                $0.id == app.id
                            }
                )
                else {

                    processObjectsChanged =
                        true

                    break
                }

                if oldApp.processIDs !=
                    app.processIDs
                {

                    processObjectsChanged =
                        true

                    break
                }

                if oldApp.processObjectIDs !=
                    app.processObjectIDs
                {

                    processObjectsChanged =
                        true

                    break
                }
            }

            guard processObjectsChanged else {

                print(
                    "ℹ️ No audio graph change required."
                )

                print("")

                return
            }
        }

        print(
            "🔄 Rebuilding audio graph..."
        )

        rebuildAudioGraph(
            applications:
                applications,

            outputUID:
                outputUID
        )
    }

    // MARK: - Output Changes

    private func handleOutputDeviceChanged(
        _ newUID:
            String
    ) {

        guard isStarted else {
            return
        }

        guard newUID != currentOutputUID else {
            return
        }

        print("")
        print("========== OUTPUT DEVICE CHANGE ==========")

        print(
            "Previous UID:",
            currentOutputUID ?? "nil"
        )

        print(
            "New UID:",
            newUID
        )

        print(
            "🔄 Rebuilding audio graph for new output..."
        )

        // -----------------------------------------
        // Refresh active applications.
        // -----------------------------------------

        let applications:
            [AudioAppInfo]

        do {

            applications =
                try AudioProcessManager.audibleApps()

        } catch {

            print(
                "❌ Failed to refresh applications after output change:"
            )

            print(error)

            print("")

            return
        }

        // -----------------------------------------
        // Rebuild with new output.
        // -----------------------------------------

        rebuildAudioGraph(
            applications:
                applications,

            outputUID:
                newUID
        )
    }

    // MARK: - Set Application Gain

    func setAppGain(
        appID:
            String,

        gain:
            Float
    ) {

        let clamped =
            max(
                0.0,
                min(
                    1.0,
                    gain
                )
            )

        // -----------------------------------------
        // Always save gain first.
        // This allows it to survive future graph
        // rebuilds.
        // -----------------------------------------

        audioQueue.async { [weak self] in

            guard let self else {
                return
            }

            self.appGains[appID] =
                clamped

            self.aggregateManager?
                .setAppGain(
                    appID:
                        appID,

                    gain:
                        clamped
                )
        }
    }

    // MARK: - Get Application Gain

    func getAppGain(
        appID:
            String
    ) -> Float? {

        // Return the saved gain first.
        if let gain =
            appGains[appID]
        {
            return gain
        }

        return aggregateManager?
            .getAppGain(
                appID:
                    appID
            )
    }

    // MARK: - Spotify Compatibility

    // Keeps old temporary Spotify UI/code working.

    func setSpotifyGain(
        _ newGain:
            Float
    ) {

        setAppGain(
            appID:
                "app:/Applications/Spotify.app",

            gain:
                newGain
        )
    }

    // MARK: - Current Applications

    func currentApps()
        -> [AudioAppInfo]
    {

        return currentApplications
    }

    // MARK: - Current Output UID

    func currentOutput()
        -> String?
    {

        return currentOutputUID
    }

    // MARK: - Stop

    func stop() {

        audioQueue.async { [weak self] in

            guard let self else {
                return
            }

            guard self.isStarted else {
                return
            }

            print("")
            print(
                "========== STOPPING SPLITSOUND =========="
            )

            // -----------------------------------------
            // Stop application monitor.
            // -----------------------------------------

            self.appMonitor?
                .stop()

            // -----------------------------------------
            // Stop output monitor.
            // -----------------------------------------

            self.outputMonitor?
                .stop()

            // -----------------------------------------
            // Stop realtime IO.
            // -----------------------------------------

            self.aggregateManager?
                .stopIO()

            // -----------------------------------------
            // Destroy aggregate.
            // -----------------------------------------

            self.aggregateManager?
                .destroyAggregate()

            // -----------------------------------------
            // Destroy all taps.
            // -----------------------------------------

            self.tapManager?
                .removeAllTaps()

            // -----------------------------------------
            // Clear active runtime state.
            //
            // Keep appGains so that if the engine is
            // started again, saved values can be reused.
            // -----------------------------------------

            self.currentApplications =
                []

            self.currentOutputUID =
                nil

            self.isStarted =
                false

            print(
                "🛑 SplitSound stopped"
            )

            print(
                "=========================================="
            )

            print("")
        }
    }
}
