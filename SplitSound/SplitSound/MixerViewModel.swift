//
//  MixerViewModel.swift
//  SplitSound
//

import Foundation
import Combine

@MainActor
final class MixerViewModel: ObservableObject {

    @Published private(set) var apps:
        [AudioAppInfo] = []

    @Published private(set) var gains:
        [String: Float] = [:]

    @Published private(set) var isRefreshing =
        false

    // MARK: - Refresh

    func refresh() {

        isRefreshing = true

        Task {

            let discoveredApps =
                (try? AudioProcessManager.audibleApps())
                ?? []

            var newGains:
                [String: Float] = [:]

            for app in discoveredApps {

                newGains[app.id] =
                    AudioEngineController.shared
                        .getAppGain(
                            appID:
                                app.id
                        )
                    ?? 0.50
            }

            apps =
                discoveredApps

            gains =
                newGains

            isRefreshing =
                false
        }
    }

    // MARK: - Set Gain

    func setGain(
        appID: String,
        value: Float
    ) {

        let clampedValue =
            max(
                0.0,
                min(
                    1.0,
                    value
                )
            )

        gains[appID] =
            clampedValue

        AudioEngineController.shared
            .setAppGain(
                appID:
                    appID,
                gain:
                    clampedValue
            )
    }

    // MARK: - Get Gain

    func gain(
        for appID: String
    ) -> Float {

        return gains[appID]
            ?? 0.50
    }
}
