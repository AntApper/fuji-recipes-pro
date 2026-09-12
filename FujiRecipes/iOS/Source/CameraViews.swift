import SwiftUI
import FujiRecipesCore
import PTPClientiOS

// MARK: - Camera Connection View

struct CameraConnectionView: View {
    @ObservedObject var manager: CameraManager
    @State private var isConnecting = false
    
    private var statusIcon: String {
        switch manager.status {
        case .disconnected: return "usb.connection"
        case .connecting: return "arrow.circlepath"
        case .connected: return "usb.connection.fill"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    private var statusColor: Color {
        switch manager.status {
        case .disconnected: return .secondary
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch manager.status {
        case .disconnected: return "Not Connected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .error: return "Error"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Status icon + text
            Image(systemName: statusIcon)
                .font(.system(size: 48))
                .foregroundStyle(statusColor)
                
                .opacity(manager.status == .connecting ? 1.0 : 0.8)
            
            Text(statusText)
                .font(.headline)
            
            // Camera info
            if let info = manager.cameraInfo {
                VStack(spacing: 4) {
                    Text(info.displayTitle)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Fuji X100VI • PTP Connected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Error message
            if let error = manager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Active settings preview
            if let settings = manager.activeSettings, !settings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Live Settings")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        if let fs = settings["FilmSim"] as? UInt32 {
                            settingChip("FS", String(fs))
                        }
                        if let dr = settings["DR"] as? UInt32 {
                            settingChip("DR", String(dr))
                        }
                        if let hl = settings["Highlight"] as? UInt32 {
                            settingChip("HL", String(Int32(bitPattern: hl)))
                        }
                        if let sh = settings["Shadow"] as? UInt32 {
                            settingChip("SH", String(Int32(bitPattern: sh)))
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.08).cornerRadius(8))
            }
            
            // Action button
            Button {
                Task {
                    if manager.status == .connected {
                        manager.disconnect()
                    } else {
                        isConnecting = true
                        defer { isConnecting = false }
                        await manager.connect(using: IOSSession())
                    }
                }
            } label: {
                HStack {
                    Image(systemName: manager.status == .connected ? "xmark.circle.fill" : "plus.circle.fill")
                    Text(manager.status == .connected ? "Disconnect Camera" : "Connect Camera")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(manager.status == .connected ? .orange : .green)
            .disabled(isConnecting)
            .controlSize(.large)
            
            // Apply recipe to camera
            if manager.status == .connected {
                Text("Connected! Use the ⚙️ Load to Slot button on any recipe to apply it to the camera.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
    
    private func settingChip(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }
}
