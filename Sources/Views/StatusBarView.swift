import SwiftUI

struct StatusBarView: View {
    let isScanning: Bool
    let progress: Double      // 0…1
    let currentPath: String
    let filesScanned: Int
    let bytesScanned: Int64
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Progress bar strip (height = 2px, always present while scanning)
            if isScanning || progress > 0 {
                ScanProgressBar(value: progress, isScanning: isScanning)
                    .frame(maxWidth: .infinity)
                    .frame(height: UIConstants.StatusBar.progressStripHeight)
                    .transition(.opacity)
            }

            // Labels row
            HStack(spacing: UIConstants.General.defaultSpacing) {
                if isScanning {
                    // Spinning activity indicator
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(UIConstants.StatusBar.spinnerScale)

                    Text("Scanning")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if !currentPath.isEmpty {
                        Text(currentPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: UIConstants.General.defaultSpacing)

                    if filesScanned > 0 {
                        Text("\(filesScanned) files · \(ByteCountFormatter.formattedSize(bytesScanned))")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    
                    // Cancel button
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel scan")
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(filesScanned > 0 ? .green : .secondary)

                    if filesScanned > 0 {
                        Text("Done · \(filesScanned) files · \(ByteCountFormatter.formattedSize(bytesScanned))")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    } else {
                        Text("Ready")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, UIConstants.StatusBar.horizontalPadding)
            .padding(.vertical, UIConstants.StatusBar.verticalPadding)
            .frame(height: UIConstants.StatusBar.height)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .animation(.easeInOut(duration: 0.25), value: isScanning)
    }
}

// ─────────────────────────────────────────────────────────────
// The narrow animated bar
// ─────────────────────────────────────────────────────────────
private struct ScanProgressBar: View {
    let value: Double   // 0…1
    let isScanning: Bool

    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(Color.accentColor.opacity(0.15))

                // Fill
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.8), Color.accentColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * max(0, min(1, value)))
                    .animation(.easeInOut(duration: 0.4), value: value)

                // Shimmer overlay (only while scanning)
                if isScanning {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0),
                                    .white.opacity(0.45),
                                    .white.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * 0.3)
                        .offset(x: shimmerOffset * geo.size.width)
                        .onAppear {
                            withAnimation(
                                .linear(duration: 1.6)
                                .repeatForever(autoreverses: false)
                            ) {
                                shimmerOffset = 1.2
                            }
                        }
                }
            }
            .clipped()
        }
    }
}
