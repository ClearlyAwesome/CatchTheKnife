import SwiftUI

struct HUD: View {
    @ObservedObject var gc: GameController
    @Binding var theme: Int

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    gc.togglePause()
                }) {
                    Image(systemName: gc.paused ? "play.fill" : "pause.fill")
                }
                .padding(10)

                Spacer()

                Menu {
                    ForEach(Themes.indices, id: \.self) { i in
                        Button(Themes[i].name) {
                            theme = i
                            gc.requestTheme(i)
                        }
                    }
                } label: {
                    Image(systemName: "paintpalette")
                }
                .padding(10)

                if Store.shared.removeAds {
                    Label("Ads removed", systemImage: "checkmark.seal.fill")
                        .padding(10)
                }

                Button(Store.shared.removeAds ? "\u2014" : "Remove Ads") {
                    Task {
                        _ = await Store.shared.buyRemoveAds()
                    }
                }
                .disabled(Store.shared.removeAds)
                .padding(10)
            }
            .foregroundStyle(.white)

            HStack(spacing: 14) {
                Toggle("Daily", isOn: $gc.dailyMode)
                    .labelsHidden()
                    .onChange(of: gc.dailyMode) { _ in
                        gc.applyDailyMode()
                    }
                Button("Slow-Mo (Ad)") {
                    gc.requestSlowMo()
                }
                .disabled(!Store.shared.removeAds && gc.slowMoActive)
            }
            .padding(.top, 4)
            .foregroundStyle(.white)

            Spacer()

            if gc.showRevive {
                VStack(spacing: 12) {
                    Text("Missed it!")
                        .font(.title2)
                        .bold()
                    HStack {
                        Button("Revive (Ad)") {
                            gc.revive()
                        }
                        Button("Restart") {
                            gc.cancelReviveAndRestart()
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}
