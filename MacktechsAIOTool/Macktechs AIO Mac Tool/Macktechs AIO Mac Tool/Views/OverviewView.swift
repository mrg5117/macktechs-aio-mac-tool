//
//  OverviewView.swift
//  Macktechs AIO Mac Tool
//

import SwiftUI

struct OverviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Overview")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Hardware and system overview coming soon.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Overview")
    }
}

#Preview {
    OverviewView()
}
