//
//  EmptyChatView.swift
//  Pi Dev
//

import SwiftUI

struct EmptyChatView: View {
  var body: some View {
    Text("π")
      .font(.system(size: 32, weight: .thin, design: .serif))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
