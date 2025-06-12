import Foundation
import SwiftData

@Model
final class Chat: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Message.chat) var messages: [Message]
    var cachedInputText: String
    
    init(id: UUID = UUID(), title: String, createdAt: Date = Date(), messages: [Message] = [], cachedInputText: String = "") {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.messages = messages
        self.cachedInputText = cachedInputText
    }
}

@Model
final class Message: Identifiable {
    @Attribute(.unique) var id: UUID
    var text: String
    var isUser: Bool
    var createdAt: Date
    @Relationship var chat: Chat?
    
    init(id: UUID = UUID(), text: String, isUser: Bool, createdAt: Date = Date(), chat: Chat? = nil) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.createdAt = createdAt
        self.chat = chat
    }
}
