//
//  CrashLogsView.swift
//  Macktechs AIO Mac Tool
//

import SwiftUI

struct CrashLogsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Crash Logs")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Recent crash logs and diagnostics coming soon.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Crash Logs")
    }
}

#Preview {
    CrashLogsView()
}
