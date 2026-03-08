import SwiftUI

struct PathTextField: View {
    let pathString: String
    let onSubmit: (String) -> Void
    
    @State private var inputPath: String = ""
    
    var body: some View {
        HStack(spacing: UIConstants.General.smallSpacing) {
            Image(systemName: "internaldrive.fill")
                .foregroundColor(.blue)
            TextField("Path", text: $inputPath)
                .textFieldStyle(.plain)
                .onSubmit {
                    onSubmit(inputPath)
                }
        }
        .padding(.horizontal, UIConstants.Tree.iconTextSpacing)
        .padding(.vertical, UIConstants.General.smallSpacing)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(UIConstants.General.cornerRadius)
        .overlay(RoundedRectangle(cornerRadius: UIConstants.General.cornerRadius).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        .onAppear {
            inputPath = pathString
        }
        .onChange(of: pathString) { _, newValue in
            inputPath = newValue
        }
    }
}

