import SwiftUI

struct ContentView: View {
    @StateObject var stt = SpeechRecognizer()

    var body: some View {
        VStack(spacing: 20) {
            Text(stt.text)
                .padding()

            HStack {
                Button("Start") { stt.start() }
                Button("Stop") { stt.stop() }
            }
        }
        .padding()
    }
}
