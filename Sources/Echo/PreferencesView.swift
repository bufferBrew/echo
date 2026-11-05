import SwiftUI

struct PreferencesView: View {
    @ObservedObject var recorder: ShortcutRecorder

    var body: some View {
        VStack(alignment: .leading, spacing: EchoStyle.inset) {
            HStack(spacing: EchoStyle.large) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: EchoStyle.small) {
                    Text("Echo").font(.title2.weight(.semibold))
                    Text("A little memory for your clipboard.")
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: EchoStyle.large) {
                    Text("Open clipboard history").font(.headline)
                    Text("Use this shortcut from any app, then choose a clip to paste.")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack(spacing: EchoStyle.medium) {
                        Text(recorder.isRecording ? "Press shortcut…" : recorder.displayString)
                            .font(.system(.body, design: .monospaced).weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(EchoStyle.medium)
                            .background(EchoStyle.surface, in: RoundedRectangle(cornerRadius: EchoStyle.radius))
                            .accessibilityLabel("Current shortcut: \(recorder.displayString)")
                        Button(recorder.isRecording ? "Cancel" : "Change…") {
                            if recorder.isRecording { recorder.cancelRecording() }
                            else { recorder.startRecording() }
                        }
                    }
                    HStack {
                        Text(recorder.isRecording ? "Include ⌘, ⌥, ⌃, or ⇧. Press Esc to cancel." : "Default: ⌘⇧V")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Restore Default") { recorder.resetToDefault() }
                            .disabled(recorder.isRecording || (recorder.keyCode == HotKeyPreference.defaultKeyCode && recorder.modifiers == HotKeyPreference.defaultModifiers))
                    }
                    if let error = recorder.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Shortcut error: \(error)")
                    }
                }
                .padding(EchoStyle.medium)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: EchoStyle.large) {
                    Label("Quick paste", systemImage: "keyboard").font(.headline)
                    Text("Allow Accessibility access so Echo can paste a selected clip into your previous app. Without access, clips are copied for you to paste with ⌘V.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Open Accessibility Settings…") { PasteSimulator.openAccessibilitySettings() }
                }
                .padding(EchoStyle.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Label("300 recent clips plus pins, stored on this Mac.", systemImage: "internaldrive")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(EchoStyle.inset)
        .frame(minWidth: 420, idealWidth: 460, maxWidth: .infinity)
        .background(EchoStyle.background)
        .onDisappear { recorder.cancelRecording() }
    }
}
