import SwiftUI

private let sayings: [String] = [
    "Gotta cache 'em all...",
    "Snorlax is blocking the road. Loading in progress...",
    "Pikachu, I choose you! (Also your card data.)",
    "Used WAIT. It's super effective!",
    "Professor Oak says: there's a time and place for everything, but not now.",
    "Slowpoke is fetching your cards. He'll get there. Eventually.",
    "MissingNo. is NOT in your collection. Pinky promise.",
    "Your rival already loaded their app. No pressure.",
    "Jigglypuff sang the servers to sleep. Waking them up...",
    "Team Rocket's blasting off to fetch your data!",
    "Mewtwo is reading the card database with its mind.",
    "Asking Alakazam to instantly load everything...",
    "Checking that your deck isn't banned in tournament play...",
    "Brock is cooking. Data will be ready when it's ready.",
    "Gary was here. Your card data is a loser. Just kidding.",
]

struct LaunchLoadingView: View {
    @State private var sayingIndex = 0
    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)

                    Text("Just TCG")
                        .font(.largeTitle.bold())
                }

                Spacer()

                VStack(spacing: 20) {
                    ZStack {
                        Text(sayings[sayingIndex])
                            .id(sayingIndex)
                            .transition(.opacity)
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
                    .frame(minHeight: 48, alignment: .center)
                    .animation(.easeInOut(duration: 0.4), value: sayingIndex)

                    ProgressView()
                }

                Spacer()
                    .frame(height: 48)
            }
        }
        .onReceive(timer) { _ in
            withAnimation {
                sayingIndex = (sayingIndex + 1) % sayings.count
            }
        }
    }
}
