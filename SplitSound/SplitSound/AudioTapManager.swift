//
//  AudioTapManager.swift
//  SplitSound
//

import Foundation
import CoreAudio

final class AudioTapManager {

    private var taps:
        [String: AudioHardwareTap] = [:]

    // MARK: - Create Tap

    @discardableResult
    func createTap(
        appID: String,
        processObjectIDs: [AudioObjectID],
        outputDeviceUID: String
    ) -> AudioHardwareTap? {

        guard !processObjectIDs.isEmpty else {

            print(
                "❌ No process objects for:",
                appID
            )

            return nil
        }

        do {

            let system =
                AudioHardwareSystem.shared

            print("")
            print(
                "========== CREATE AUDIO TAP =========="
            )

            print(
                "App:",
                appID
            )

            print(
                "Process Objects:",
                processObjectIDs
            )

            let description =
                CATapDescription(
                    processes:
                        processObjectIDs,
                    deviceUID:
                        outputDeviceUID,
                    stream:
                        0
                )

            description.name =
                "SplitSound \(appID)"

            description.uuid =
                UUID()

            description.isPrivate =
                true

            // Prevent the application's original
            // output from playing directly.
            //
            // SplitSound will render the processed
            // version through the aggregate device.
            description.muteBehavior =
                .muted

            print(
                "Creating tap..."
            )

            let tap =
                try system.makeProcessTap(
                    description:
                        description
                )

            guard let tap else {

                print(
                    "❌ Core Audio returned nil tap."
                )

                return nil
            }

            taps[appID] =
                tap

            print(
                "✅ Tap created"
            )

            print(
                "Tap UID:",
                try tap.uid
            )

            print(
                "======================================"
            )

            print("")

            return tap

        } catch {

            print(
                "❌ Failed to create tap for:",
                appID
            )

            print(error)

            return nil
        }
    }

    // MARK: - Create Taps For Applications

    func createTaps(
        applications: [AudioAppInfo],
        outputDeviceUID: String
    ) -> [String] {

        var createdAppIDs:
            [String] = []

        for app in applications {

            guard
                createTap(
                    appID:
                        app.id,

                    processObjectIDs:
                        app.processObjectIDs,

                    outputDeviceUID:
                        outputDeviceUID
                ) != nil
            else {

                print(
                    "⚠️ Failed to create tap:",
                    app.name
                )

                continue
            }

            createdAppIDs.append(
                app.id
            )
        }

        print("")
        print(
            "Created audio taps:",
            createdAppIDs.count
        )

        return createdAppIDs
    }

    // MARK: - Tap

    func tap(
        for appID: String
    ) -> AudioHardwareTap? {

        return taps[appID]
    }

    // MARK: - Tap UID

    func tapUID(
        for appID: String
    ) -> String? {

        guard
            let tap =
                taps[appID]
        else {
            return nil
        }

        return try? tap.uid
    }

    // MARK: - Tap UIDs In Order

    func tapUIDs(
        for appIDs: [String]
    ) -> [String] {

        var result:
            [String] = []

        for appID in appIDs {

            guard
                let uid =
                    tapUID(
                        for:
                            appID
                    )
            else {
                continue
            }

            result.append(uid)
        }

        return result
    }

    // MARK: - All Taps

    func allTaps()
        -> [(appID: String, tap: AudioHardwareTap)] {

        return taps.map {
            (
                appID:
                    $0.key,

                tap:
                    $0.value
            )
        }
    }

    // MARK: - Remove Tap

    func removeTap(
        for appID: String
    ) {

        guard
            taps.removeValue(
                forKey:
                    appID
            ) != nil
        else {
            return
        }

        print(
            "🗑️ Removed tap:",
            appID
        )
    }

    // MARK: - Remove All

    func removeAllTaps() {

        let system =
            AudioHardwareSystem.shared

        for (appID, tap) in taps {

            do {

                try system.destroyProcessTap(
                    tap
                )

                print(
                    "🗑️ Destroyed tap:",
                    appID
                )

            } catch {

                print(
                    "⚠️ Failed to destroy tap:",
                    appID
                )

                print(error)
            }
        }

        taps.removeAll()

        print(
            "🗑️ All Core Audio taps removed"
        )
    }
}
