//
//  BrowserHealthView.swift
//  Macktechs AIO Mac Tool
//

import SwiftUI

struct BrowserHealthView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browser Health Check")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Run the browser health scan to see results here.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Browser Health Check")
    }
}

#Preview {
    BrowserHealthView()
}
