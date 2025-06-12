//
//  FoundationModelChatBotApp.swift
//  FoundationModelChatBot
//
//  Created by Aaron Butler on 6/10/25.
//

import SwiftUI
import SwiftData
import Foundation

@main
struct FoundationModelChatBotApp: App {
    var body: some Scene {
        WindowGroup {
            ChatListView()
                .modelContainer(for: [Chat.self, Message.self])
        }
    }
}
