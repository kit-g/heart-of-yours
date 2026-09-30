import SwiftUI

/// Heart on the wrist (#175): a remote for the workout the phone is running.
///
/// The phone owns the workout; this app holds nothing of its own but the last
/// state the phone sent (#182). Until then there is nothing to say, and no copy
/// to say it with — every string arrives from Dart, already localised — so the
/// first screen is a picture, not a sentence.
@main
struct HeartWatchApp: App {
    var body: some Scene {
        WindowGroup {
            AwaitingPhone()
        }
    }
}

/// Before the phone has sent anything: the iPhone symbol, which is the whole
/// instruction, and reads in every language.
struct AwaitingPhone: View {
    var body: some View {
        Image(systemName: "iphone")
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(.secondary)
    }
}

#Preview {
    AwaitingPhone()
}
