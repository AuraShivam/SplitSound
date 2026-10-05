# SplitSound 🎧

> A native macOS per-application audio volume mixer built with Swift, SwiftUI, and Core Audio.

SplitSound is a macOS desktop application designed to give you independent volume control over applications that are currently producing audio. Instead of changing the system-wide output level, SplitSound creates a Core Audio processing path for individual applications and exposes a separate volume control for each one.

## ✨ Features

- 🎚️ **Per-application volume control** — adjust the volume of individual audio-producing apps independently.
- 🔊 **Automatic audio-app detection** — discovers applications that are currently producing audio.
- 🔄 **Dynamic app monitoring** — detects when audio applications start or stop and updates the mixer.
- 🎧 **Core Audio process taps** — creates a dedicated audio tap for each detected application.
- 🎛️ **Aggregate audio mixing** — combines application audio into a private aggregate output path.
- 🔌 **Default output tracking** — monitors the current macOS output device and rebuilds the audio graph when it changes.
- ⚡ **Native macOS UI** — built with SwiftUI for a lightweight, native desktop experience.
- 🔒 **Local-first design** — audio processing is handled locally on the Mac; no cloud service or external API is required by the current project.

## 🖥️ Tech Stack

| Technology | Purpose |
|---|---|
| **Swift 5** | Application and audio-engine implementation |
| **SwiftUI** | Native macOS user interface |
| **Core Audio** | Audio discovery, process taps, routing, and mixing |
| **Xcode** | Development and build environment |
| **macOS** | Target platform |

## 🏗️ Architecture

SplitSound is organized around a small set of dedicated managers coordinated by `AudioEngineController`.

```text
                         ┌──────────────────────┐
                         │    SwiftUI UI        │
                         │     ContentView      │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │  MixerViewModel      │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │ AudioEngineController│
                         └──────┬───────┬───────┘
                                │       │
                 ┌──────────────┘       └──────────────┐
                 ▼                                     ▼
        ┌──────────────────┐                   ┌──────────────────┐
        │ AudioAppMonitor  │                   │ AudioOutputMonitor│
        │ Active apps      │                   │ Output changes   │
        └────────┬─────────┘                   └────────┬─────────┘
                 │                                      │
                 └────────────────┬─────────────────────┘
                                  ▼
                       ┌──────────────────────┐
                       │  AudioTapManager     │
                       │  One tap per app     │
                       └──────────┬───────────┘
                                  │
                                  ▼
                       ┌──────────────────────┐
                       │ AudioAggregateManager│
                       │ Aggregate mixer      │
                       └──────────┬───────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ Physical Output  │
                         └──────────────────┘
```

### Core components

#### `AudioEngineController.swift`
The central coordinator for the audio engine. It:

- Starts the audio system.
- Tracks the active output device.
- Tracks audible applications.
- Creates and removes process taps.
- Preserves per-application gain values.
- Rebuilds the audio graph when applications or output devices change.

#### `AudioTapManager.swift`
Responsible for creating and removing Core Audio process taps. SplitSound creates a private tap for each application and keeps the tap associated with the application's identifier.

#### `AudioAggregateManager.swift`
Builds the private aggregate audio device used to combine the tapped application streams with the physical output device.

#### `AudioProcessManager.swift`
Discovers applications and their associated audio process objects.

#### `AudioAppMonitor.swift`
Polls the currently audible applications and detects changes in the application/process set so the audio graph can be rebuilt when necessary.

#### `AudioOutputMonitor.swift`
Monitors changes to the default output device.

#### `MixerViewModel.swift`
Connects the audio engine to the SwiftUI interface and manages the application gain values exposed to the UI.

#### `ContentView.swift`
The main SwiftUI interface. It displays active audio applications and a volume slider for each application.

## 📁 Project Structure

```text
SplitSound/
├── SplitSound/
│   ├── AudioAggregateManager.swift
│   ├── AudioAppMonitor.swift
│   ├── AudioEngineController.swift
│   ├── AudioIOManager.swift
│   ├── AudioOutputMonitor.swift
│   ├── AudioProcessManager.swift
│   ├── AudioTapManager.swift
│   ├── ContentView.swift
│   ├── Info.plist
│   ├── MixerViewModel.swift
│   ├── SplitSoundApp.swift
│   └── Assets.xcassets
│
├── SplitSound.xcodeproj/
└── .gitignore
```

## 📥 Download and Run

### Option 1 — Download the source code from GitHub

You can download the latest source code directly from the repository:

1. Open the [SplitSound GitHub repository](https://github.com/AuraShivam/SplitSound).
2. Click **Code**.
3. Select **Download ZIP**.
4. Extract the downloaded ZIP file.
5. Open `SplitSound/SplitSound.xcodeproj` in Xcode.
6. Select the **SplitSound** target.
7. Build and run the application.

> **Note:** The current repository provides the source code rather than a pre-built `.app` release. You need Xcode to build SplitSound from source.

### Option 2 — Clone with Git

If Git is installed on your Mac:

```bash
git clone https://github.com/AuraShivam/SplitSound.git
cd SplitSound
open SplitSound/SplitSound.xcodeproj
```

### Requirements


- macOS **26.5 or later**
- Xcode with Swift 5 support
- A Mac capable of running the target macOS version

The current Xcode project sets the deployment target to macOS 26.5.

### Build and Run

1. Clone the repository:

```bash
git clone https://github.com/AuraShivam/SplitSound.git
cd SplitSound
```

2. Open the Xcode project:

```bash
open SplitSound/SplitSound.xcodeproj
```

3. Select the **SplitSound** target in Xcode.
4. Build and run the application.

### Audio Permission

SplitSound declares a system-audio capture usage description because it needs access to application audio streams for per-app mixing.

When macOS requests the required permission, allow access for SplitSound and then relaunch the app if necessary.

## 🎚️ How It Works

At startup, `AudioEngineController` initializes the audio subsystem and discovers the current default output device.

SplitSound then:

1. Detects applications currently producing audio.
2. Creates a Core Audio process tap for each detected application.
3. Applies an independent gain value to each application.
4. Creates a private aggregate device containing those tapped streams and the physical output.
5. Renders the resulting audio through the current output device.
6. Continues monitoring applications and the output device.
7. Rebuilds the audio graph when the active applications or output device changes.

This architecture allows the application-level gain controls to operate independently instead of relying only on macOS's global output volume.

## 🧪 Current Status

SplitSound is an active development project.

The current repository contains the core audio-engine implementation and SwiftUI mixer interface. The project is still being refined, so behavior and compatibility may change as the audio pipeline evolves.

## 🛣️ Roadmap

Planned improvements may include:

- [ ] Per-app mute controls
- [ ] Persistent per-app volume settings
- [ ] Menu bar / background mode
- [ ] Smoother app discovery and graph rebuilds
- [ ] Improved error handling and user-facing diagnostics
- [ ] Better handling of application and output-device edge cases
- [ ] Packaging and distribution workflow for end users
- [ ] Code signing and notarized releases

## 🔐 Privacy

SplitSound is designed as a local macOS utility. The current project does not require a backend, cloud account, or external API for its audio-mixing pipeline.

Because SplitSound works with other applications' audio streams, macOS system-audio capture permission is required.

## 🤝 Contributing

Contributions, bug reports, and ideas are welcome.

Before opening a pull request:

1. Reproduce the issue on the latest `main` branch.
2. Keep changes focused and documented.
3. Verify that the project builds successfully in Xcode.
4. Avoid committing generated build artifacts or local Xcode user data.

## 📄 License

- The app is fully functional, but it is still a work in progress and has not been extensively refined or polished.
- The current version focuses mainly on **per-application volume mixing**.
- Feel free to use, experiment with, modify, and build upon the project however you like.
- This project is primarily shared for **learning, experimentation, and personal use**.

## 👨‍💻 Author

**Shivam Chaudhary**

GitHub: [@AuraShivam](https://github.com/AuraShivam)

---

⭐ If you find SplitSound interesting, consider starring the repository and following the project as it develops.
