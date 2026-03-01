//
//  SecurityView.swift
//  Macktechs AIO Tool
//
//  Placeholder for future security & malware scanning.
//

import SwiftUI

struct SecurityView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Security & Malware")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Security & malware scanning coming soon.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Security & Malware")
    }
}

#Preview {
    SecurityView()
}
