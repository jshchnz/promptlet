//
//  SettingsView.swift
//  Promptlet
//
//  Created by Assistant on 8/30/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        TabView {
            GeneralSettingsTab(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(0)
            
            KeyboardSettingsTab(settings: settings)
                .tabItem {
                    Label("Keyboard", systemImage: "keyboard")
                }
                .tag(1)
            
            AppearanceSettingsTab(settings: settings)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(2)
            
            DebugSettingsTab(settings: settings)
                .tabItem {
                    Label("Debug", systemImage: "hammer")
                }
                .tag(3)
        }
        .frame(width: 680, height: 420)
    }
}

#Preview {
    SettingsView(settings: AppSettings())
}