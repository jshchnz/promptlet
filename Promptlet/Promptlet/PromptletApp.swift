//
//  PromptletApp.swift
//  Promptlet
//
//  Created by Josh Cohenzadeh on 8/29/25.
//

import SwiftUI

@main
struct PromptletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView(settings: appDelegate.appSettings)
        }
    }
}
