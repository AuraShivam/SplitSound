//
//  ContentView.swift
//  SplitSound
//

import SwiftUI

struct ContentView: View {

    @StateObject private var viewModel =
        MixerViewModel()

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 20
        ) {

            HStack {

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    Text("SplitSound")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(
                        "\(viewModel.apps.count) active audio applications"
                    )
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {

                    viewModel.refresh()

                } label: {

                    Image(
                        systemName:
                            "arrow.clockwise"
                    )
                }
                .help("Refresh applications")
            }

            Divider()

            if viewModel.apps.isEmpty {

                VStack(
                    spacing: 12
                ) {

                    Image(
                        systemName:
                            "speaker.slash"
                    )
                    .font(.system(size: 35))

                    Text(
                        "No active audio applications"
                    )
                    .font(.headline)

                    Text(
                        "Start audio in an application and refresh."
                    )
                    .foregroundStyle(.secondary)
                }
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity
                )

            } else {

                ScrollView {

                    LazyVStack(
                        spacing: 18
                    ) {

                        ForEach(
                            viewModel.apps
                        ) { app in

                            AppMixerRow(
                                app:
                                    app,

                                gain:
                                    Binding(
                                        get: {

                                            viewModel.gain(
                                                for:
                                                    app.id
                                            )

                                        },
                                        set: { newValue in

                                            viewModel.setGain(
                                                appID:
                                                    app.id,

                                                value:
                                                    newValue
                                            )
                                        }
                                    )
                            )
                        }
                    }
                    .padding(
                        .vertical,
                        8
                    )
                }
            }
        }
        .padding(28)
        .frame(
            minWidth:
                700,

            minHeight:
                450
        )
        .task {

            // Give the audio engine a moment to initialize.
            try? await Task.sleep(
                for:
                    .milliseconds(500)
            )

            viewModel.refresh()
        }
    }
}

private struct AppMixerRow:
    View {

    let app:
        AudioAppInfo

    @Binding var gain:
        Float

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            HStack {

                Image(
                    systemName:
                        "waveform"
                )
                .frame(
                    width:
                        28
                )

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        2
                ) {

                    Text(
                        app.name
                    )
                    .font(
                        .headline
                    )

                    Text(
                        app.bundleID
                            ?? "Unknown"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()

                Text(
                    "\(Int(gain * 100))%"
                )
                .monospacedDigit()
                .frame(
                    width:
                        55
                )
            }

            Slider(
                value:
                    Binding(
                        get: {
                            Double(
                                gain
                            )
                        },
                        set: { value in

                            gain =
                                Float(
                                    value
                                )
                        }
                    ),
                in:
                    0...1
            )

            HStack {

                Text("0%")
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                Spacer()

                Text("100%")
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(
                cornerRadius:
                    14
            )
            .fill(
                Color(
                    nsColor:
                        .windowBackgroundColor
                )
            )
        )
    }
}

#Preview {
    ContentView()
}
