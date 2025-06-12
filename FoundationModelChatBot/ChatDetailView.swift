//
//  ChatDetailView.swift
//  FoundationModelChatBot
//
//  Created by Aaron Butler on 6/10/25.
//

import SwiftUI
import SwiftData
import FoundationModels
import Combine

struct ChatDetailView: View {
    @Bindable var chat: Chat
    
    @State private var inputText: String = ""
    @State private var textEditorHeight: CGFloat = 40
    
    @State private var session: LanguageModelSession?
    @State private var response: String.PartiallyGenerated?
    
    @FocusState private var textFieldFocused: Bool
    
    let backgroundColor = Color(red: 33/255.0, green: 33/255.0, blue: 33/255.0)
    let botMessageColor = Color(red: 23/255.0, green: 23/255.0, blue: 23/255.0)
    let userMessageColor = Color(red: 48/255.0, green: 48/255.0, blue: 48/255.0)
    
    var chatHistory: String {
        chat.messages.map {
            "\(($0.isUser ? "User" : "Bot")): \($0.text)"
        }
        .joined(separator: "\n")
    }
    
    init(chat: Chat) {
        self._chat = .init(chat)
    }
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    let sortedMessages = chat.messages.sorted { $0.createdAt < $1.createdAt }
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(sortedMessages) { message in
                            HStack {
                                if message.isUser { Spacer() }
                                Text(LocalizedStringKey(message.text))
                                    .padding(20)
                                    .foregroundStyle(.white)
                                    .background(message.isUser ? userMessageColor : botMessageColor)
                                    .cornerRadius(25)
                                    .contextMenu {
                                        Button(action: {
                                            #if canImport(UIKit)
                                            UIPasteboard.general.string = message.text
                                            #elseif canImport(AppKit)
                                            let pasteboard = NSPasteboard.general
                                            pasteboard.clearContents()
                                            pasteboard.setString(message.text, forType: .string)
                                            #endif
                                        }) {
                                            Label("Copy", systemImage: "doc.on.doc")
                                        }
                                    }
                                if !message.isUser { Spacer() }
                            }
                        }
                        
                        if let response {
                            HStack {
                                Text(response)
                                    .padding(20)
                                    .foregroundStyle(.white)
                                    .background(botMessageColor)
                                    .cornerRadius(25)
                                Spacer()
                            }
                            .id("live_response")
                        }
                        
                        Color.clear.frame(height: 80).id("bottom_padding")
                    }
                    .padding()
                }
                .onChange(of: chat.messages.count) { _, _ in
                    withAnimation {
                        scrollViewProxy.scrollTo("bottom_padding", anchor: .bottom)
                    }
                }
                .onChange(of: response) { _, _ in
                    if response != nil {
                        withAnimation {
                            scrollViewProxy.scrollTo("bottom_padding", anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    scrollViewProxy.scrollTo("bottom_padding", anchor: .bottom)
                }
            }
            
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    TextField("", text: $inputText, prompt: Text("Ask anything").foregroundColor(.gray))
                        .focused($textFieldFocused)
                        .padding()
                        .frame(maxHeight: .infinity)
                        .glassEffect()
                        .tint(.white)
                        .onSubmit {
                            sendButtonPressed()
                        }
                    
                    Button {
                        sendButtonPressed()
                    } label: {
                        Image(systemName: "arrow.up")
                            .bold()
                            .padding()
                            .frame(maxHeight: .infinity)
                            .glassEffect(in: .circle)

                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .fixedSize(horizontal: false, vertical: true)
            }
//            .padding(.horizontal)
        }
        .onAppear {
            inputText = chat.cachedInputText
            textFieldFocused = true
            session = LanguageModelSession(instructions: Instructions("You are a friendly chatbot"))
            session?.prewarm()
        }
        .onDisappear {
            chat.cachedInputText = inputText
            
            guard chat.title == "New Chat", !chat.messages.isEmpty else { return }
            
            Task {
                let prompt = """
                         Previous messages: \(chat.messages.prefix(5).compactMap { "\(($0.isUser ? "User:" : "ChatBot (you):")) \($0.text)" })
                         
                         Using those messages, create a simple title for this chat (don't include any quotes or colons).
                         """
                
                do {
                    guard let response = try await session?.respond(to: prompt) else { return }
                    
                    chat.title = response.content
                } catch {
                    print(error)
                }
            }
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: chatHistory, preview: SharePreview("Share your chat history"))
                    .disabled(chat.messages.isEmpty)
            }
            #elseif os(macOS)
            ToolbarItem {
                ShareLink(item: chatHistory, preview: SharePreview("Share your chat history"))
                    .disabled(chat.messages.isEmpty)
            }
            #endif
        }
    }

    private func sendButtonPressed() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task {
            textFieldFocused = false
            do {
                try await sendMessage()
            } catch {
                print(error)
            }
        }
    }
    
    private func sendMessage() async throws {
        let userMessage = Message(text: inputText, isUser: true)
        chat.messages.append(userMessage)
        inputText = ""
        
        let prompt = """
                     Previous messages: \(chat.messages.compactMap { "\(($0.isUser ? "User:" : "ChatBot (you):")) \($0.text)" }) 
                     
                     Respond to this new user message as best as you can using markdown and don't add a label like \"ChatBot (you)\". 
                     You can use the previous messages included here as context if you are confused by the user's new message. Do not include the word "markdown" at the start of your response.
                     
                     New user message: \(userMessage.text)
                     """
        
        guard let stream = session?.streamResponse(
            generating: String.self,
            options: GenerationOptions(sampling: .random(top: 1)),
            includeSchemaInPrompt: false,
            prompt: {
                Prompt(prompt)
            }
        ) else { return }
        
        for try await partialResponse in stream {
            response = partialResponse
        }
        
        withAnimation {
            chat.messages.append(Message(text: response ?? "", isUser: false))
            response = nil
        }
    }
}

