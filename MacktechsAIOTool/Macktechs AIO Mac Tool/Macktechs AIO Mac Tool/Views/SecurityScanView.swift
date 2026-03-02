//
//  SecurityScanView.swift
//  Macktechs AIO Mac Tool
//

import SwiftUI

struct SecurityScanView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Security Scan")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Security and malware scanning coming soon.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Security Scan")
    }
}

#Preview {
    SecurityScanView()
}
