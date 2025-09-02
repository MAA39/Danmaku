import SwiftUI

struct PreferencesView: View {
    @State private var speed: Double = Double(DanmakuPrefs.speed)
    @State private var fontSize: Double = Double(DanmakuPrefs.fontSize)
    @State private var baselineY: Double = Double(DanmakuPrefs.baselineY)
    @State private var traverseSec: Double = DanmakuPrefs.overlayTraverseSec
    @State private var widthFraction: Double = DanmakuPrefs.overlayWidthFraction
    @State private var inputInsertion: Bool = DanmakuPrefs.inputInjectionEnabled
    @State private var silenceGapSec: Double = DanmakuPrefs.silenceGapSec

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
            GroupBox(label: Text("Overlay Traverse (sec)")) {
                HStack {
                    Slider(value: $traverseSec, in: 2...12, step: 0.1) { Text("") }
                    Text(String(format: "%.1f", traverseSec))
                        .frame(width: 48, alignment: .trailing)
                }
            }
            GroupBox(label: Text("Overlay Width (% of screen)")) {
                HStack {
                    Slider(value: $widthFraction, in: 0.3...1.0, step: 0.05) { Text("") }
                    Text("\(Int(widthFraction * 100))%")
                        .frame(width: 48, alignment: .trailing)
                }
            }
            GroupBox(label: Text("Input Injection")) {
                Toggle("Insert finalized chunks into focused input", isOn: $inputInsertion)
            }
            GroupBox(label: Text("Silence Gap (sec)")) {
                HStack {
                    Slider(value: $silenceGapSec, in: 0.5...5.0, step: 0.1) { Text("") }
                    Text(String(format: "%.1f", silenceGapSec))
                        .frame(width: 48, alignment: .trailing)
                }
            }
            Spacer()
        }
        .padding(16)
        .frame(width: 440, height: 460)
        .onChange(of: speed) { DanmakuPrefs.speed = CGFloat(speed) }
        .onChange(of: fontSize) { DanmakuPrefs.fontSize = CGFloat(fontSize) }
        .onChange(of: baselineY) { DanmakuPrefs.baselineY = CGFloat(baselineY) }
        .onChange(of: traverseSec) { DanmakuPrefs.overlayTraverseSec = traverseSec }
        .onChange(of: widthFraction) { DanmakuPrefs.overlayWidthFraction = widthFraction }
        .onChange(of: inputInsertion) { DanmakuPrefs.inputInjectionEnabled = inputInsertion }
        .onChange(of: silenceGapSec) { DanmakuPrefs.silenceGapSec = silenceGapSec }
    }
}

#Preview {
    PreferencesView()
}
