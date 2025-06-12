import SwiftUI
import SwiftData

struct ChatListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: [SortDescriptor(\Chat.createdAt, order: .reverse)]) var chats: [Chat]
    
    @State private var isCreatingNewChat = false
    @State private var newChat: Chat? = nil

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    chatListContent
                } detail: {
                    if let chat = chats.first {
                        ChatDetailView(chat: chat)
                    } else {
                        Text("Select or create a chat")
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                NavigationStack {
                    chatListContent
                }
            }
        }
    }
    
    private var chatListContent: some View {
        List {
            ForEach(chats) { chat in
                NavigationLink(value: chat) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chat.title)
                            .font(.headline)
                        Text(chat.messages.last?.text.prefix(80) ?? "No messages yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteChats)
        }
        .onAppear {
            for chat in chats {
                if chat.messages.isEmpty {
                    modelContext.delete(chat)
                }
                do {
                    try modelContext.save()
                } catch {
                    print(error)
                }
            }
        }
        .navigationTitle("Chats")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let chat = Chat(title: "New Chat")
                    modelContext.insert(chat)
                    newChat = chat
                    do {
                        try modelContext.save()
                    } catch {
                        print(error)
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: Chat.self) { chat in
            ChatDetailView(chat: chat)
        }
        .navigationDestination(item: $newChat) { chat in
            ChatDetailView(chat: chat)
        }
    }

    private func deleteChats(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(chats[index])
            
            do {
                try modelContext.save()
            } catch {
                print(error)
            }
        }
    }
}
