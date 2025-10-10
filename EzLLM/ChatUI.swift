//
//  ChatUI.swift
//  EzLLM

import SwiftUI

struct ChatUI: View {
    // Sidebar & sheet state
    @State private var isSidebarOpen: Bool = false
    @State private var showSettings: Bool = false
    
    // Simple chat list state (placeholder)
    @State private var chats: [String] = ["Chat1", "Chat2"]
    @State private var selectedChatIndex: Int = 0
    @State private var avatarColor: Color = .black
    
    init(initialIsSidebarOpen: Bool = false) {
        self._isSidebarOpen = State(initialValue: initialIsSidebarOpen)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Main chat area (Top bar + messages + composer)
                Chat(
                    isSidebarOpen: $isSidebarOpen,
                    chats: $chats,
                    selectedChatIndex: $selectedChatIndex,
                    onNewChat: { newChat() },
                    onOpenSettings: { showSettings = true },
                    avatarColor: $avatarColor,
                    availableWidth: geo.size.width,
                    topSafeInset: geo.safeAreaInsets.top
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Dim background when drawer is open
                if isSidebarOpen {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { isSidebarOpen = false } }
                }
                
                // Slide-in ChatList drawer
                ChatUI.ChatList(
                    chats: $chats,
                    selectedChatIndex: $selectedChatIndex,
                    topSafeInset: geo.safeAreaInsets.top,
                    onSelect: { _ in withAnimation { isSidebarOpen = false } }
                )
                .frame(width: min(320, geo.size.width * 0.85), alignment: .top)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .vertical)
                .offset(x: isSidebarOpen ? 0 : -min(320, geo.size.width * 0.85))
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.2), value: isSidebarOpen)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                Form {
                    Section("Appearance") {
                        ColorPicker("Avatar color", selection: $avatarColor, supportsOpacity: false)
                    }
                }
                .navigationTitle("Settings")
            }
        }
    }
    
    private func newChat() {
        let next = "Chat\(chats.count + 1)"
        chats.insert(next, at: 0)
        selectedChatIndex = 0
    }
    
    // MARK: - Nested types (UI only)
    private struct UIMessage: Identifiable, Equatable {
        let id = UUID()
        let isUser: Bool
        let text: String
    }
    
    private struct Chat: View {
        @Binding var isSidebarOpen: Bool
        @Binding var chats: [String]
        @Binding var selectedChatIndex: Int
        var onNewChat: () -> Void
        var onOpenSettings: () -> Void
        @Binding var avatarColor: Color
        var availableWidth: CGFloat
        var topSafeInset: CGFloat
        let restOffset: CGFloat = 5
        let headerHeight: CGFloat = 60
        let composerControlHeight: CGFloat = 44
        
        
        // Sample messages to resemble iMessage layout
        @State private var messages: [UIMessage] = [
            .init(isUser: false, text: "Hey there!"),
            .init(isUser: true, text: "Hi! How's it going?"),
            .init(isUser: false, text: "All good. Ready to test the UI."),
            .init(isUser: true, text: "Let's do it.")
        ]
        @State private var inputText: String = ""
        @State private var isRenaming: Bool = false
        @FocusState private var isNameFieldFocused: Bool
        @FocusState private var isComposerFocused: Bool
        
        private var isSendEnabled: Bool {
            !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        var body: some View {
            VStack(spacing: 0) {
                // Messages (iMessage-like bubbles) with overlay header
                ZStack(alignment: .top) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(messages) { msg in
                                    messageRow(msg)
                                        .id(msg.id)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        // Simple approach: constant inset so first bubble rests below header, no equations
                        .safeAreaInset(edge: .top) {
                            Color.clear.frame(height: 55)
                        }
                        .onTapGesture { isComposerFocused = false }
                    }
                    headerBar()
                        .frame(maxWidth: .infinity, alignment: .top)
                        .zIndex(1)
                }
                
                // Composer (no-op Send for now)
                HStack(alignment: .center, spacing: 8) {
                    ZStack(alignment: .trailing) {
                        TextField("Entry",text: $inputText,prompt: Text("Put your prompt here: ") ,axis: .vertical)
                            .font(.body)
                            .lineLimit(1...)
                            .focused($isComposerFocused)
                            .padding(.horizontal, 12)
                        
                        if !inputText.isEmpty {
                            Button {
                                inputText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                        }
                    }
                    .frame(height: composerControlHeight)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button(action: { /* no-op for now */ }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(width: composerControlHeight, height: composerControlHeight)
                            .background(
                                Circle().fill(isSendEnabled ? Color.blue : Color.gray)
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isSendEnabled)
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        
        @ViewBuilder
        private func messageRow(_ msg: UIMessage) -> some View {
            HStack(alignment: .bottom) {
                if msg.isUser {
                    Spacer(minLength: 24)
                    Text(msg.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .frame(maxWidth: availableWidth * 0.7, alignment: .trailing)
                } else {
                    Text(msg.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                        .frame(maxWidth: availableWidth * 0.7, alignment: .leading)
                    Spacer(minLength: 24)
                }
            }
            .padding(.horizontal, 4)
        }
        
        @ViewBuilder
        private func headerBar() -> some View {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button { withAnimation { isSidebarOpen.toggle() } } label: {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: Circle())
                            .contentShape(Circle())
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(avatarColor)
                            .font(.system(size: 18))
                            .frame(width: 28, height: 28)
                        
                        TextField("Chat name", text: Binding(
                            get: { (0..<chats.count).contains(selectedChatIndex) ? chats[selectedChatIndex] : "" },
                            set: { name in if (0..<chats.count).contains(selectedChatIndex) { chats[selectedChatIndex] = name } }
                        ))
                        .textFieldStyle(.plain)
                        .font(.body)
                        .frame(maxWidth: 60, alignment: .center)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                        .disabled(!isRenaming)
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            isRenaming = false
                            isNameFieldFocused = false
                        }
                        
                        Button {
                            withAnimation { isRenaming.toggle() }
                            isNameFieldFocused = isRenaming
                        } label: {
                            Image(systemName: isRenaming ? "checkmark" : "pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .contentShape(Circle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    
                    
                    Spacer()
                    
                    Button { onOpenSettings() } label: {
                        Image(systemName: "gear")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: Circle())
                            .contentShape(Circle())
                    }
                }
                .padding(.horizontal,12)
                .padding(.vertical,8)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.1), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .background(.regularMaterial)
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: topSafeInset)
            }
            .clipShape(Rectangle())
            .contentShape(Rectangle())
            .onTapGesture { isComposerFocused = false }
            .ignoresSafeArea(edges: .top)
        }
        
    }
    
    private struct ChatList: View {
        @Binding var chats: [String]
        @Binding var selectedChatIndex: Int
        var topSafeInset: CGFloat
        var onSelect: (Int) -> Void
        
        init(chats: Binding<[String]>, selectedChatIndex: Binding<Int>, topSafeInset: CGFloat, onSelect: @escaping (Int) -> Void) {
            self._chats = chats
            self._selectedChatIndex = selectedChatIndex
            self.topSafeInset = topSafeInset
            self.onSelect = onSelect
        }
        
        var body: some View {
            ZStack(alignment: .topLeading) {
                // Bottom: single rectangular glass background for the whole drawer
                Rectangle()
                    .fill(Color.clear)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassEffect(.clear.interactive(), in: Rectangle())
                    .clipShape(Rectangle())
                    .ignoresSafeArea()
                
                // Top: content
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chats")
                        .font(.title.bold())
                        .padding(.top, topSafeInset)
                        .padding(.horizontal, 12)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(chats.indices), id: \.self) { idx in
                                HStack {
                                    Text(chats[idx]).lineLimit(1)
                                    Spacer()
                                    if idx == selectedChatIndex {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 44)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedChatIndex = idx
                                    onSelect(idx)
                                }
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ChatUI()
}

#Preview("Sidebar") {
    ChatUI(initialIsSidebarOpen: true)
}
