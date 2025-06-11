//
//  ContentView.swift
//  FoundationModelChatBot
//
//  Created by Aaron Butler on 6/10/25.
//

import SwiftUI
import FoundationModels
import Combine

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct ContentView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Hi! How can I help you today?", isUser: false)
    ]
    @State private var inputText: String = ""
    @State private var textEditorHeight: CGFloat = 40

    @State private var session: LanguageModelSession?
    @State private var response: String.PartiallyGenerated?
    
    var body: some View {
        VStack {
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            HStack {
                                if message.isUser { Spacer() }
                                Text(message.text)
                                    .padding(10)
                                    .foregroundStyle(message.isUser ? .white : .black)
                                    .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                                if !message.isUser { Spacer() }
                            }
                        }
                        
                        if let response {
                            HStack {
                                Text(response)
                                    .padding(10)
                                    .foregroundStyle(Color.black)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                                Spacer()
                            }
                            .id("live_response")
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last?.id {
                        withAnimation {
                            scrollViewProxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: response) { _, _ in
                    if response != nil {
                        withAnimation {
                            scrollViewProxy.scrollTo("live_response", anchor: .bottom)
                        }
                    }
                }
            }
            Divider()
            HStack(alignment: .center) {
                TextField("Message Foundation Model", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                Button("Send") {
                    Task {
                        do {
                            try await sendMessage()
                        } catch {
                            print(error)
                        }
                    }
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .onAppear {
            session = LanguageModelSession(instructions: Instructions("You are a friendly chatbot"))
            session?.prewarm()
        }
    }

    private func sendMessage() async throws {
        let userMessage = ChatMessage(text: inputText, isUser: true)
        messages.append(userMessage)
        inputText = ""
        
        guard let stream = session?.streamResponse(
            generating: String.self,
            options: GenerationOptions(sampling: .greedy),
            includeSchemaInPrompt: false,
            prompt: { Prompt(userMessage.text) }
        ) else { return }

        for try await partialResponse in stream {
            response = partialResponse
        }
        
        withAnimation {
            messages.append(ChatMessage(text: response ?? "", isUser: false))
            response = nil
        }
    }
}

#Preview {
    ContentView()
}
