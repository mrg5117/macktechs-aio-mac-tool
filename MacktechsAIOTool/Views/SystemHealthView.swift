//
//  SystemHealthView.swift
//  Macktechs AIO Mac Tool
//
//  Placeholder for future system health tools.
//

import SwiftUI

struct SystemHealthView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "speedometer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("System Health")
                .font(.title2)
                .fontWeight(.semibold)
            Text("System health tools coming soon.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("System Health")
    }
}

#Preview {
    SystemHealthView()
}
