//
//  AudioProcessManager.swift
//  SplitSound
//

import Foundation
import CoreAudio
import AppKit
import Darwin

struct AudioAppInfo: Identifiable, Sendable {

    let id: String
    let name: String
    let bundleID: String?
    let appPath: String?
    let processIDs: [pid_t]
    let processObjectIDs: [AudioObjectID]
}

final class AudioProcessManager {

    // MARK: - Scan

    static func scan() {

        do {

            let apps = try audibleApps()

            print("")
            print("========== AUDIBLE APPLICATIONS ==========")
            print("Count:", apps.count)
            print("")

            if apps.isEmpty {
                print("No active output applications found.")
            }

            for app in apps {

                print("🔊", app.name)

                print(
                    "   Bundle:",
                    app.bundleID ?? "Unknown"
                )

                print(
                    "   App Path:",
                    app.appPath ?? "Unknown"
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

            print(
                "=========================================="
            )

            print("")

        } catch {

            print(
                "❌ Failed to scan audio applications:"
            )

            print(error)
        }
    }

    // MARK: - Find Audible Applications

    static func audibleApps() throws
        -> [AudioAppInfo] {

        let system =
            AudioHardwareSystem.shared

        let processes =
            try system.processes

        var groups:
            [String: AppGroup] = [:]

        print("")
        print(
            "========== CORE AUDIO PROCESS DIAGNOSTIC =========="
        )

        print(
            "Total Core Audio processes:",
            processes.count
        )

        print("")

        for process in processes {

            let processObjectID =
                process.id

            let pid =
                try process.pid

            let processBundleID =
                try? process.bundleID

            let processName =
                try? process.name

            let runningOutput =
                try? process.isRunningOutput

            // -----------------------------------------
            // Diagnostic information.
            // -----------------------------------------

            print(
                "[PROCESS]",
                "name:",
                processName ?? "Unknown",
                "| bundle:",
                processBundleID ?? "Unknown",
                "| output:",
                runningOutput.map {
                    String($0)
                } ?? "ERROR",
                "| PID:",
                pid,
                "| ObjectID:",
                processObjectID
            )

            // -----------------------------------------
            // Never capture SplitSound itself.
            // -----------------------------------------

            if processBundleID ==
                "com.shivam.SplitSound" {

                continue
            }

            // -----------------------------------------
            // Only active output processes.
            // -----------------------------------------

            guard
                runningOutput == true
            else {

                continue
            }

            // -----------------------------------------
            // Resolve process -> actual .app
            // -----------------------------------------

            let application =
                resolveOwningApplication(
                    pid: pid
                )

            let appName: String
            let appBundleID: String?
            let appPath: String?

            if let application {

                appName =
                    application.name

                appBundleID =
                    application.bundleID

                appPath =
                    application.path

            } else {

                // Never throw away an active audio process
                // just because it could not be resolved to
                // a normal .app bundle.

                appName =
                    processName
                    ?? processBundleID
                    ?? "Audio Process \(pid)"

                appBundleID =
                    processBundleID

                appPath =
                    nil
            }

            // -----------------------------------------
            // Group by application path when possible.
            // Otherwise use bundle ID.
            // -----------------------------------------

            let groupKey: String

            if let appPath,
               !appPath.isEmpty {

                groupKey =
                    "app:\(appPath)"

            } else if let appBundleID,
                      !appBundleID.isEmpty {

                groupKey =
                    "bundle:\(appBundleID)"

            } else {

                groupKey =
                    "process:\(pid):\(processObjectID)"
            }

            // -----------------------------------------
            // Add process to group.
            // -----------------------------------------

            if var group =
                groups[groupKey] {

                group.processIDs.append(
                    pid
                )

                group.processObjectIDs.append(
                    processObjectID
                )

                groups[groupKey] =
                    group

            } else {

                groups[groupKey] =
                    AppGroup(
                        name:
                            appName,

                        bundleID:
                            appBundleID,

                        path:
                            appPath,

                        processIDs:
                            [pid],

                        processObjectIDs:
                            [processObjectID]
                    )
            }
        }

        print(
            "=================================================="
        )

        print("")

        return groups
            .map { key, group in

                AudioAppInfo(
                    id:
                        key,

                    name:
                        group.name,

                    bundleID:
                        group.bundleID,

                    appPath:
                        group.path,

                    processIDs:
                        group.processIDs,

                    processObjectIDs:
                        group.processObjectIDs
                )
            }
            .sorted {

                $0.name.localizedCaseInsensitiveCompare(
                    $1.name
                ) == .orderedAscending
            }
    }

    // MARK: - Application Group

    private struct AppGroup {

        let name: String
        let bundleID: String?
        let path: String?

        var processIDs:
            [pid_t]

        var processObjectIDs:
            [AudioObjectID]
    }

    // MARK: - Resolved Application

    private struct ResolvedApplication {

        let name: String
        let bundleID: String?
        let path: String
    }

    // MARK: - Resolve Application

    private static func resolveOwningApplication(
        pid: pid_t
    ) -> ResolvedApplication? {

        // -----------------------------------------
        // Method 1:
        // NSRunningApplication
        // -----------------------------------------

        if let runningApplication =
            NSRunningApplication(
                processIdentifier: pid
            ) {

            // Best case: NSRunningApplication knows
            // the executable URL.
            if let executableURL =
                runningApplication.executableURL {

                if let appURL =
                    findOutermostApp(
                        from:
                            executableURL
                    ) {

                    if let application =
                        readApplication(
                            from:
                                appURL
                        ) {

                        print(
                            "   ↳ Resolved using NSRunningApplication:",
                            application.name
                        )

                        return application
                    }
                }
            }

            // Second NSRunningApplication fallback.
            if let bundleURL =
                runningApplication.bundleURL {

                if let appURL =
                    findOutermostApp(
                        from:
                            bundleURL
                    ) {

                    if let application =
                        readApplication(
                            from:
                                appURL
                        ) {

                        print(
                            "   ↳ Resolved using bundleURL:",
                            application.name
                        )

                        return application
                    }
                }
            }
        }

        // -----------------------------------------
        // Method 2:
        // macOS proc_pidpath()
        //
        // This is especially useful for helper
        // processes such as Chrome Helper.
        // -----------------------------------------

        guard
            let executablePath =
                processExecutablePath(
                    pid: pid
                )
        else {

            return nil
        }

        print(
            "   ↳ proc_pidpath:",
            executablePath
        )

        let executableURL =
            URL(
                fileURLWithPath:
                    executablePath
            )

        // -----------------------------------------
        // Walk from the executable to the OUTERMOST
        // .app bundle.
        // -----------------------------------------

        guard
            let applicationURL =
                findOutermostApp(
                    from:
                        executableURL
                )
        else {

            return nil
        }

        // -----------------------------------------
        // Read application metadata.
        // -----------------------------------------

        if let application =
            readApplication(
                from:
                    applicationURL
            ) {

            print(
                "   ↳ Resolved using proc_pidpath:",
                application.name
            )

            return application
        }

        return nil
    }

    // MARK: - Process Executable Path

    private static func processExecutablePath(
        pid: pid_t
    ) -> String? {

        // 4 KB is more than enough for normal
        // macOS executable paths.
        let bufferSize = 4096

        var buffer =
            [CChar](
                repeating:
                    0,
                count:
                    bufferSize
            )

        let result =
            buffer.withUnsafeMutableBufferPointer {
                pointer -> Int32 in

                guard
                    let baseAddress =
                        pointer.baseAddress
                else {

                    return -1
                }

                return proc_pidpath(
                    pid,
                    baseAddress,
                    UInt32(bufferSize)
                )
            }

        guard result > 0 else {

            return nil
        }

        return String(
            cString:
                buffer
        )
    }

    // MARK: - Find Outermost .app

    private static func findOutermostApp(
        from url: URL
    ) -> URL? {

        var current =
            url.standardizedFileURL

        var outermostApp:
            URL?

        while current.path != "/" {

            if current.pathExtension
                .lowercased() == "app" {

                outermostApp =
                    current
            }

            current =
                current.deletingLastPathComponent()
        }

        return outermostApp
    }

    // MARK: - Read Application Metadata

    private static func readApplication(
        from appURL: URL
    ) -> ResolvedApplication? {

        guard
            let bundle =
                Bundle(
                    url:
                        appURL
                )
        else {

            return nil
        }

        let displayName =
            bundle.object(
                forInfoDictionaryKey:
                    "CFBundleDisplayName"
            ) as? String

            ?? bundle.object(
                forInfoDictionaryKey:
                    "CFBundleName"
            ) as? String

            ?? appURL
                .deletingPathExtension()
                .lastPathComponent

        return ResolvedApplication(
            name:
                displayName,

            bundleID:
                bundle.bundleIdentifier,

            path:
                appURL.path
        )
    }
}
