import SwiftUI

struct PreferencesView: View {
    @State private var speed: Double = Double(DanmakuPrefs.speed)
    @State private var fontSize: Double = Double(DanmakuPrefs.fontSize)
    @State private var baselineY: Double = Double(DanmakuPrefs.baselineY)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: Text("Scrolling Speed (px/s)")) {
                HStack {
                    Slider(value: $speed, in: 20...150, step: 1) { Text("") }
                    Text("\(Int(speed))")
                        .frame(width: 48, alignment: .trailing)
                }
            }
            GroupBox(label: Text("Font Size")) {
                HStack {
                    Slider(value: $fontSize, in: 14...48, step: 1) { Text("") }
                    Text("\(Int(fontSize))")
                        .frame(width: 48, alignment: .trailing)
                }
            }
            GroupBox(label: Text("Top Baseline Y (pt from top)")) {
                HStack {
                    Slider(value: $baselineY, in: 40...300, step: 1) { Text("") }
                    Text("\(Int(baselineY))")
                        .frame(width: 48, alignment: .trailing)
                }
            }
            Spacer()
        }
        .padding(16)
        .frame(width: 400, height: 220)
        .onChange(of: speed) { DanmakuPrefs.speed = CGFloat(speed) }
        .onChange(of: fontSize) { DanmakuPrefs.fontSize = CGFloat(fontSize) }
        .onChange(of: baselineY) { DanmakuPrefs.baselineY = CGFloat(baselineY) }
    }
}

#Preview {
    PreferencesView()
}
