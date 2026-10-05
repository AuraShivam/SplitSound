//
//  AudioIOManager.swift
//  SplitSound
//

import Foundation
import CoreAudio
import Darwin
import Synchronization

final class GainState: @unchecked Sendable {

    let value =
        Atomic<Float>(0.50)

    func set(
        _ newValue: Float
    ) {

        let clamped =
            max(
                0.0,
                min(
                    1.0,
                    newValue
                )
            )

        value.store(
            clamped,
            ordering:
                .relaxed
        )
    }

    func get() -> Float {

        return value.load(
            ordering:
                .relaxed
        )
    }
}

final class AudioIOManager {

    private var ioProcID:
        AudioDeviceIOProcID?

    private var deviceID:
        AudioObjectID?

    private var gainStates:
        [String: GainState] = [:]

    // MARK: - Gain

    func setGain(
        for appID: String,
        value: Float
    ) {

        guard
            let state =
                gainStates[appID]
        else {

            print(
                "⚠️ No gain state for:",
                appID
            )

            return
        }

        state.set(
            value
        )

        print(
            "🎚️",
            appID,
            "gain:",
            state.get()
        )
    }

    func getGain(
        for appID: String
    ) -> Float? {

        return gainStates[appID]?
            .get()
    }

    // MARK: - Start

    func start(
        aggregateDevice: AudioHardwareAggregateDevice,
        appIDs: [String],
        tapUIDs: [String]
    ) {

        deviceID =
            aggregateDevice.id

        guard
            !appIDs.isEmpty
        else {

            print(
                "❌ Cannot start IO: no app IDs."
            )

            return
        }

        // -----------------------------------------
        // Create one gain state per application.
        // -----------------------------------------

        var states:
            [String: GainState] = [:]

        for appID in appIDs {

            states[appID] =
                GainState()
        }

        self.gainStates =
            states

        // Capture the reference-type states.
        // The realtime callback does NOT capture self.
        let sharedGainStates =
            states

        let orderedAppIDs =
            appIDs

        var newIOProcID:
            AudioDeviceIOProcID?

        let status =
            AudioDeviceCreateIOProcIDWithBlock(
                &newIOProcID,
                aggregateDevice.id,
                nil
            ) {
                _,
                inputData,
                _,
                outputData,
                _
                in

                let inputBuffers =
                    UnsafeMutableAudioBufferListPointer(
                        UnsafeMutablePointer(
                            mutating:
                                inputData
                        )
                    )

                let outputBuffers =
                    UnsafeMutableAudioBufferListPointer(
                        outputData
                    )

                guard
                    outputBuffers.count > 0
                else {
                    return
                }

                // ------------------------------------------------
                // This first implementation assumes the current
                // output device is output-only.
                //
                // Your realme Buds T310 currently has no input
                // streams, so the aggregate's tap input streams
                // begin at input buffer 0.
                // ------------------------------------------------

                guard
                    inputBuffers.count >=
                    orderedAppIDs.count
                else {

                    // Safety: output silence rather than
                    // accidentally rendering unrelated input.
                    for outputIndex
                        in 0..<outputBuffers.count {

                        let outputBuffer =
                            outputBuffers[
                                outputIndex
                            ]

                        guard
                            let outputPointer =
                                outputBuffer.mData
                        else {
                            continue
                        }

                        memset(
                            outputPointer,
                            0,
                            Int(
                                outputBuffer
                                    .mDataByteSize
                            )
                        )
                    }

                    return
                }

                // ------------------------------------------------
                // Clear output first.
                // ------------------------------------------------

                for outputIndex
                    in 0..<outputBuffers.count {

                    let outputBuffer =
                        outputBuffers[
                            outputIndex
                        ]

                    guard
                        let outputPointer =
                            outputBuffer.mData
                    else {
                        continue
                    }

                    memset(
                        outputPointer,
                        0,
                        Int(
                            outputBuffer
                                .mDataByteSize
                        )
                    )
                }

                // ------------------------------------------------
                // Mix each application tap into output.
                // ------------------------------------------------

                for appIndex
                    in 0..<orderedAppIDs.count {

                    let appID =
                        orderedAppIDs[
                            appIndex
                        ]

                    guard
                        let gainState =
                            sharedGainStates[
                                appID
                            ]
                    else {
                        continue
                    }

                    let currentGain =
                        gainState.value.load(
                            ordering:
                                .relaxed
                        )

                    let inputBuffer =
                        inputBuffers[
                            appIndex
                        ]

                    guard
                        let inputPointer =
                            inputBuffer.mData
                    else {
                        continue
                    }

                    let inputSamples =
                        inputPointer
                            .assumingMemoryBound(
                                to:
                                    Float.self
                            )

                    let inputSampleCount =
                        Int(
                            inputBuffer
                                .mDataByteSize
                        )
                        /
                        MemoryLayout<Float>
                            .size

                    // --------------------------------------------
                    // Current output is expected to be one
                    // stereo Float32 interleaved buffer.
                    // --------------------------------------------

                    guard
                        outputBuffers.count > 0
                    else {
                        continue
                    }

                    let outputBuffer =
                        outputBuffers[0]

                    guard
                        let outputPointer =
                            outputBuffer.mData
                    else {
                        continue
                    }

                    let outputSamples =
                        outputPointer
                            .assumingMemoryBound(
                                to:
                                    Float.self
                            )

                    let outputSampleCount =
                        Int(
                            outputBuffer
                                .mDataByteSize
                        )
                        /
                        MemoryLayout<Float>
                            .size

                    let sampleCount =
                        min(
                            inputSampleCount,
                            outputSampleCount
                        )

                    for sampleIndex
                        in 0..<sampleCount {

                        outputSamples[
                            sampleIndex
                        ] +=
                            inputSamples[
                                sampleIndex
                            ]
                            *
                            currentGain
                    }
                }

                // ------------------------------------------------
                // Temporary safety limiter.
                //
                // Multiple apps can sum above [-1, 1].
                // For now clamp the result.
                //
                // We will replace this with proper mix headroom
                // / limiting later.
                // ------------------------------------------------

                guard
                    outputBuffers.count > 0
                else {
                    return
                }

                let outputBuffer =
                    outputBuffers[0]

                guard
                    let outputPointer =
                        outputBuffer.mData
                else {
                    return
                }

                let outputSamples =
                    outputPointer
                        .assumingMemoryBound(
                            to:
                                Float.self
                        )

                let outputSampleCount =
                    Int(
                        outputBuffer
                            .mDataByteSize
                    )
                    /
                    MemoryLayout<Float>
                        .size

                for sampleIndex
                    in 0..<outputSampleCount {

                    let sample =
                        outputSamples[
                            sampleIndex
                        ]

                    if sample > 1.0 {

                        outputSamples[
                            sampleIndex
                        ] = 1.0

                    } else if sample < -1.0 {

                        outputSamples[
                            sampleIndex
                        ] = -1.0
                    }
                }
            }

        guard
            status == noErr,
            let newIOProcID
        else {

            print(
                "❌ Failed to create IOProc. OSStatus:",
                status
            )

            return
        }

        ioProcID =
            newIOProcID

        do {

            try aggregateDevice.start(
                IOProcID:
                    newIOProcID
            )

            print(
                "✅ Multi-app Aggregate IO started"
            )

            print(
                "🎚️ Initial app gain: 0.5"
            )

            print(
                "🎛️ Managed applications:",
                appIDs
            )

        } catch {

            print(
                "❌ Failed to start aggregate IO:"
            )

            print(error)
        }
    }

    // MARK: - Stop

    func stop() {

        guard
            let deviceID,
            let ioProcID
        else {
            return
        }

        do {

            try AudioHardwareDevice(
                id:
                    deviceID
            ).stop(
                IOProcID:
                    ioProcID
            )

            print(
                "✅ Aggregate IO stopped"
            )

        } catch {

            print(
                "❌ Failed to stop aggregate IO:"
            )

            print(error)
        }

        let status =
            AudioDeviceDestroyIOProcID(
                deviceID,
                ioProcID
            )

        if status != noErr {

            print(
                "⚠️ Failed to destroy IOProc. OSStatus:",
                status
            )
        }

        self.ioProcID =
            nil

        self.deviceID =
            nil
    }
}
