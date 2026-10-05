import Foundation
import CoreAudio

final class AudioAggregateManager {

    // MARK: - State

    private var aggregateDevice: AudioHardwareAggregateDevice?
    private var audioIOManager: AudioIOManager?

    // MARK: - Output Devices

    static func printOutputDevices() {

        do {

            let system = AudioHardwareSystem.shared
            let devices = try system.devices

            print("")
            print("========== OUTPUT DEVICES ==========")

            for device in devices {

                let name = try device.name
                let outputConfiguration = try device.outputStreamConfiguration

                guard !outputConfiguration.isEmpty else {
                    continue
                }

                print(
                    "Name: \(name) | ID: \(device.id)"
                )
            }

            print("====================================")
            print("")

        } catch {

            print("❌ Failed to read output devices:")
            print(error)
        }
    }

    // MARK: - Default Output

    static func printDefaultOutputDevice() {

        do {

            let system = AudioHardwareSystem.shared

            guard let device = try system.defaultOutputDevice else {

                print("❌ No default output device.")
                return
            }

            let name = try device.name
            let uid = try device.uid

            print("")
            print("========== DEFAULT OUTPUT ==========")

            print(
                "Name:",
                name
            )

            print(
                "Object ID:",
                device.id
            )

            print(
                "UID:",
                uid
            )

            print("====================================")
            print("")

        } catch {

            print("❌ Failed to get default output:")
            print(error)
        }
    }

    // MARK: - Default Output UID

    static func defaultOutputDeviceUID() -> String? {

        do {

            let system = AudioHardwareSystem.shared

            guard let device = try system.defaultOutputDevice else {

                print("❌ No default output device.")
                return nil
            }

            return try device.uid

        } catch {

            print("❌ Failed to get default output device UID:")
            print(error)

            return nil
        }
    }

    // MARK: - Create Multi-App Aggregate

    func createAggregate(
        tapUIDs: [String],
        outputDeviceUID: String
    ) {

        guard !tapUIDs.isEmpty else {

            print(
                "❌ Cannot create aggregate: no taps."
            )

            return
        }

        do {

            let system = AudioHardwareSystem.shared

            // -----------------------------------------
            // Find physical output device.
            // -----------------------------------------

            guard let outputDevice =
                    try system.device(forUID: outputDeviceUID)
            else {

                print(
                    "❌ Could not find output device for UID:",
                    outputDeviceUID
                )

                return
            }

            // -----------------------------------------
            // Determine physical output channels.
            // -----------------------------------------

            let physicalOutputConfiguration =
                try outputDevice.outputStreamConfiguration

            let physicalOutputChannels =
                physicalOutputConfiguration.reduce(
                    UInt32(0)
                ) { total, buffer in

                    total + buffer.mNumberChannels
                }

            guard physicalOutputChannels > 0 else {

                print(
                    "❌ Output device has no output channels."
                )

                return
            }

            // -----------------------------------------
            // Build one aggregate tap entry per app.
            // -----------------------------------------

            let tapEntries: [[String: Any]] =
                tapUIDs.map { tapUID in

                    [
                        kAudioSubTapUIDKey:
                            tapUID,

                        kAudioSubTapDriftCompensationKey:
                            true
                    ]
                }

            // -----------------------------------------
            // Configure physical output as:
            //
            // INPUT  = 0 channels
            // OUTPUT = physical output channels
            //
            // This prevents a physical microphone from
            // becoming an unexpected aggregate input.
            // -----------------------------------------

            let physicalSubDevice: [String: Any] = [

                kAudioSubDeviceUIDKey:
                    outputDeviceUID,

                kAudioSubDeviceDriftCompensationKey:
                    true,

                kAudioSubDeviceInputChannelsKey:
                    UInt32(0),

                kAudioSubDeviceOutputChannelsKey:
                    physicalOutputChannels
            ]

            // -----------------------------------------
            // Aggregate UID.
            // -----------------------------------------

            let aggregateUID =
                "com.shivam.SplitSound.aggregate."
                + UUID().uuidString

            // -----------------------------------------
            // Aggregate description.
            // -----------------------------------------

            let description: [String: Any] = [

                kAudioAggregateDeviceNameKey:
                    "SplitSound Mixer",

                kAudioAggregateDeviceUIDKey:
                    aggregateUID,

                kAudioAggregateDeviceIsPrivateKey:
                    true,

                kAudioAggregateDeviceIsStackedKey:
                    false,

                kAudioAggregateDeviceTapAutoStartKey:
                    true,

                // Physical output is clock master.
                kAudioAggregateDeviceMainSubDeviceKey:
                    outputDeviceUID,

                kAudioAggregateDeviceSubDeviceListKey:
                    [
                        physicalSubDevice
                    ],

                kAudioAggregateDeviceTapListKey:
                    tapEntries
            ]

            print("")
            print("========== MULTI-APP AGGREGATE ==========")

            print(
                "Creating private aggregate..."
            )

            print(
                "Output UID:",
                outputDeviceUID
            )

            print(
                "Physical output channels:",
                physicalOutputChannels
            )

            print(
                "Tap count:",
                tapUIDs.count
            )

            for (index, tapUID) in
                tapUIDs.enumerated()
            {

                print(
                    "Tap \(index):",
                    tapUID
                )
            }

            // -----------------------------------------
            // Create aggregate.
            // -----------------------------------------

            let aggregate =
                try system.makeAggregateDevice(
                    description: description
                )

            guard let aggregate else {

                print(
                    "❌ Aggregate creation returned nil."
                )

                return
            }

            self.aggregateDevice = aggregate

            print(
                "✅ Multi-app aggregate created"
            )

            print(
                "Aggregate ID:",
                aggregate.id
            )

            print(
                "Name:",
                try aggregate.name
            )

            // -----------------------------------------
            // Inspect subtaps.
            // -----------------------------------------

            let subtaps =
                try aggregate.subtaps

            print(
                "Subtaps:",
                subtaps.count
            )

            for (index, tap) in
                subtaps.enumerated()
            {

                let uid = try tap.uid

                print(
                    "   Subtap \(index):",
                    uid
                )
            }

            // -----------------------------------------
            // Inspect aggregate input layout.
            // -----------------------------------------

            let inputConfiguration =
                try aggregate.inputStreamConfiguration

            let inputChannels =
                inputConfiguration.reduce(
                    UInt32(0)
                ) { total, buffer in

                    total + buffer.mNumberChannels
                }

            let outputConfiguration =
                try aggregate.outputStreamConfiguration

            let outputChannels =
                outputConfiguration.reduce(
                    UInt32(0)
                ) { total, buffer in

                    total + buffer.mNumberChannels
                }

            print(
                "Aggregate input buffers:",
                inputConfiguration.count
            )

            print(
                "Aggregate input channels:",
                inputChannels
            )

            print(
                "Aggregate output buffers:",
                outputConfiguration.count
            )

            print(
                "Aggregate output channels:",
                outputChannels
            )

            print("========================================")
            print("")

        } catch {

            print("")
            print("❌ Multi-app aggregate error:")
            print(error)
            print("")
        }
    }

    // MARK: - Aggregate Status

    func printAggregateStatus() {

        guard let aggregateDevice else {

            print(
                "❌ No aggregate device exists."
            )

            return
        }

        do {

            let alive =
                try aggregateDevice.isAlive

            print("")
            print("========== AGGREGATE STATUS ==========")

            print(
                "Name:",
                try aggregateDevice.name
            )

            print(
                "Object ID:",
                aggregateDevice.id
            )

            print(
                "Is Alive:",
                alive
            )

            print("======================================")
            print("")

        } catch {

            print(
                "❌ Failed to read aggregate:"
            )

            print(error)
        }
    }

    // MARK: - Start IO

    func startIO(
        appIDs: [String],
        tapUIDs: [String]
    ) {

        guard let aggregateDevice else {

            print(
                "❌ No aggregate device available."
            )

            return
        }

        guard !appIDs.isEmpty else {

            print(
                "❌ No applications available for IO."
            )

            return
        }

        guard appIDs.count == tapUIDs.count else {

            print(
                "❌ App/tap count mismatch."
            )

            print(
                "Applications:",
                appIDs.count
            )

            print(
                "Taps:",
                tapUIDs.count
            )

            return
        }

        let manager =
            AudioIOManager()

        manager.start(
            aggregateDevice:
                aggregateDevice,

            appIDs:
                appIDs,

            tapUIDs:
                tapUIDs
        )

        audioIOManager =
            manager
    }

    // MARK: - App Gain

    func setAppGain(
        appID: String,
        gain: Float
    ) {

        guard let audioIOManager else {

            print(
                "❌ Audio IO manager unavailable."
            )

            return
        }

        audioIOManager.setGain(
            for:
                appID,

            value:
                gain
        )
    }

    func getAppGain(
        appID: String
    ) -> Float? {

        return audioIOManager?
            .getGain(
                for:
                    appID
            )
    }

    // MARK: - Stop IO

    func stopIO() {

        audioIOManager?.stop()

        audioIOManager = nil
    }

    // MARK: - Destroy Aggregate

    func destroyAggregate() {

        guard let aggregateDevice else {
            return
        }

        do {

            try AudioHardwareSystem.shared
                .destroyAggregateDevice(
                    aggregateDevice
                )

            print(
                "🗑️ Aggregate device destroyed:",
                aggregateDevice.id
            )

        } catch {

            print(
                "⚠️ Failed to destroy aggregate:"
            )

            print(error)
        }

        self.aggregateDevice = nil
    }
}
