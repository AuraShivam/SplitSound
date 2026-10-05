//
//  SplitSoundApp.swift
//  SplitSound
//

import SwiftUI

@main
struct SplitSoundApp: App {

    init() {

        AudioEngineController.shared.start()
    }

    var body: some Scene {

        WindowGroup {

            ContentView()
        }
    }
}
