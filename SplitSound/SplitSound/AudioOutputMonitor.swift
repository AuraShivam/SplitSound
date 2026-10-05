//
//  AudioOutputMonitor.swift
//  SplitSound
//
//  Created by shivam chaudhary on 27/09/26.
//

import Foundation

final class AudioOutputMonitor: @unchecked Sendable {

    // MARK: - Queue

    private let monitorQueue = DispatchQueue(
        label: "com.shivam.SplitSound.output-monitor",
        qos: .utility
    )

    // MARK: - State

    private var timer: DispatchSourceTimer?
    private var isMonitoring = false

    private var currentOutputUID: String?

    private var onOutputChanged: ((String) -> Void)?

    // MARK: - Start

    func start(
        initialOutputUID: String,
        onOutputChanged: @escaping (String) -> Void
    ) {
        monitorQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isMonitoring else { return }

            self.currentOutputUID = initialOutputUID
            self.onOutputChanged = onOutputChanged

            let timer = DispatchSource.makeTimerSource(
                queue: self.monitorQueue
            )

            timer.schedule(
                deadline: .now() + .milliseconds(500),
                repeating: .milliseconds(500),
                leeway: .milliseconds(100)
            )

            timer.setEventHandler { [weak self] in
                self?.checkOutputDevice()
            }

            self.timer = timer
            self.isMonitoring = true

            timer.resume()

            print("✅ AudioOutputMonitor started")
            print("🔊 Initial output UID: \(initialOutputUID)")
        }
    }

    // MARK: - Check Output Device

    private func checkOutputDevice() {
        guard isMonitoring else {
            return
        }

        guard let newUID =
                AudioAggregateManager.defaultOutputDeviceUID()
        else {
            print("⚠️ Could not determine current default output device.")
            return
        }

        guard newUID != currentOutputUID else {
            return
        }

        let oldUID = currentOutputUID

        currentOutputUID = newUID

        print("========================================")
        print("🔄 DEFAULT OUTPUT DEVICE CHANGED")
        print("   Old UID: \(oldUID ?? "nil")")
        print("   New UID: \(newUID)")
        print("========================================")

        onOutputChanged?(newUID)
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

            self.currentOutputUID = nil
            self.onOutputChanged = nil

            print("🛑 AudioOutputMonitor stopped")
        }
    }
}
