//
//  NetworkDiagnosticsView.swift
//  Macktechs AIO Mac Tool
//

import SwiftUI

struct NetworkDiagnosticsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Diagnostics")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Network and connectivity diagnostics coming soon.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Network Diagnostics")
    }
}

#Preview {
    NetworkDiagnosticsView()
}
