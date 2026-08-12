//
//  Provider.swift
//  Pi Dev
//

import SwiftUI

struct Provider<Content: View>: View {
  @ViewBuilder let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    self.content
      .foregroundStyle(appLabel)
  }
}
