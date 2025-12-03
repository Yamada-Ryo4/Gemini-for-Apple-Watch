import SwiftUI
import PhotosUI

// --- 主视图 ---
struct ChatView: View {
    @StateObject var viewModel = ChatViewModel()
    // 给输入区域一个专门的 ID，方便自动滚动到底部时露出它
    @Namespace private var bottomID
    // 控制历史记录页面的显示
    @State private var showHistory = false
    
    var body: some View {
        NavigationStack {
            // 使用 ScrollViewReader 实现自动滚动
            ScrollViewReader { proxy in
                ScrollView {
                    // 核心布局：所有内容都在一个 VStack 里，输入框在最后
                    LazyVStack(alignment: .leading, spacing: 12) {
                        
                        // 1. 顶部占位
                        Spacer().frame(height: 5)
                        
                        // 2. 空状态欢迎语
                        if viewModel.currentMessages.isEmpty {
                            EmptyStateView()
                        }
                        
                        // 3. 消息列表
                        ForEach(viewModel.currentMessages) { msg in
                            PrettyMessageBubble(message: msg)
                                .id(msg.id)
                        }
                        
                        // 4. 思考动画
                        if viewModel.isLoading {
                            ThinkingIndicator()
                        }
                        
                        // 5. 底部输入区域
                        BottomInputArea(viewModel: viewModel)
                            .id(bottomID) // 绑定 ID 用于滚动
                            .padding(.top, 10) // 与上一条消息拉开一点距离
                            .padding(.bottom, 10) // 底部留白
                    }
                    .padding(.horizontal, 8)
                }
                // 监听消息变化，自动滚到底部
                .onChange(of: viewModel.currentMessages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.currentMessages.last?.text) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                // 刚进入页面时，也滚到底部
                .onAppear {
                    scrollToBottom(proxy: proxy)
                }
            }
            .navigationTitle(viewModel.currentModelName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左上角：设置
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: SettingsView(viewModel: viewModel)) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
                
                // 右上角：历史记录列表
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryListView(viewModel: viewModel, isPresented: $showHistory)
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }
}

// --- 组件：历史记录列表视图 ---
struct HistoryListView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            List {
                // 新建对话按钮
                Button {
                    viewModel.createNewSession()
                    isPresented = false // 关闭列表，回到主界面
                } label: {
                    HStack {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.green)
                        Text("新建对话")
                            .fontWeight(.bold)
                    }
                }
                
                Section(header: Text("历史对话")) {
                    if viewModel.sessions.isEmpty {
                        Text("暂无历史").font(.caption).foregroundColor(.gray)
                    }
                    
                    ForEach(viewModel.sessions) { session in
                        Button {
                            viewModel.selectSession(session)
                            isPresented = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(session.title.isEmpty ? "新对话" : session.title)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Text(session.lastModified.formatted(date: .numeric, time: .shortened))
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if viewModel.currentSessionId == session.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                        }
                        .listItemTint(viewModel.currentSessionId == session.id ? .blue.opacity(0.1) : nil)
                    }
                    .onDelete(perform: viewModel.deleteSession)
                }
            }
            .navigationTitle("对话列表")
        }
    }
}

// --- 组件：跟随滚动的底部输入区域 ---
struct BottomInputArea: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        let hasImage = viewModel.selectedImageData != nil
        
        HStack(spacing: 8) {
            // 1. 相册按钮
            PhotosPicker(selection: $viewModel.selectedImageItem, matching: .images) {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 36, height: 36)
                    
                    if hasImage {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .onChange(of: viewModel.selectedImageItem) { _, _ in viewModel.loadImage() }
            
            // 2. 文本输入区域 (ZStack 遮罩技巧)
            ZStack(alignment: .leading) {
                // 底层：胶囊背景
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 36)
                
                // 中层：显示的文字
                Text(viewModel.inputText.isEmpty ? "发送消息..." : viewModel.inputText)
                    .font(.system(size: 15))
                    .foregroundColor(viewModel.inputText.isEmpty ? .gray : .white)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                
                // 顶层：透明的系统输入框
                TextField("placeholder", text: $viewModel.inputText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .opacity(0.02) // 看不见但能点击
                    .contentShape(Rectangle())
            }
            
            // 3. 发送按钮
            if !viewModel.inputText.isEmpty || hasImage {
                Button(action: viewModel.sendMessage) {
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// --- 组件：空状态 ---
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.largeTitle)
                .foregroundStyle(LinearGradient(colors: [.blue, .green], startPoint: .topLeading, endPoint: .bottomTrailing))
                .opacity(0.8)
            Text("Gemini")
                .font(.headline)
            Text("向下滚动开始对话")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

// --- 组件：消息气泡 (增强版：支持 ### 标题 + 原生 Markdown) ---
struct PrettyMessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.role == .user { Spacer() }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // 1. 图片显示
                if let imgData = message.imageData, let uiImage = UIImage(data: imgData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                
                // 2. 文本显示 (混合解析模式)
                if !message.text.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        // 将文本按行分割，为了处理标题
                        // 使用 Array(... .enumerated()) 是为了给 ForEach 提供稳定的 id
                        ForEach(Array(message.text.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
                            
                            // 手动解析标题语法
                            if line.hasPrefix("### ") {
                                Text(String(line.dropFirst(4)))
                                    .font(.system(size: 16, weight: .bold)) // 三级标题
                                    .foregroundColor(.white)
                            } else if line.hasPrefix("## ") {
                                Text(String(line.dropFirst(3)))
                                    .font(.system(size: 17, weight: .heavy)) // 二级标题
                                    .foregroundColor(.white)
                            } else if line.hasPrefix("# ") {
                                Text(String(line.dropFirst(2)))
                                    .font(.system(size: 18, weight: .black)) // 一级标题
                                    .foregroundColor(.white)
                            } else {
                                // 普通行：使用 .init() 激活原生 Markdown (支持加粗、链接)
                                // 如果是空行，需要给一个最小高度，否则会被 VStack 忽略导致段落挤在一起
                                if line.isEmpty {
                                    Text(" ")
                                        .font(.system(size: 8)) // 稍微小一点的间距
                                } else {
                                    Text(.init(line))
                                        .font(.system(size: 15))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.role == .user
                        ? AnyShapeStyle(LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.gray.opacity(0.3))
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .mask(RoundedRectangle(cornerRadius: 16))
                    .tint(.yellow) // 设置链接颜色为黄色，在蓝色背景上更清晰
                }
            }
            
            if message.role == .model { Spacer() }
        }
    }
}

// --- 组件：思考动画 ---
struct ThinkingIndicator: View {
    @State private var blink = false
    var body: some View {
        HStack {
            Circle().frame(width: 6, height: 6).opacity(blink ? 0.3 : 1)
            Circle().frame(width: 6, height: 6).opacity(blink ? 0.3 : 1).delay(0.2)
            Circle().frame(width: 6, height: 6).opacity(blink ? 0.3 : 1).delay(0.4)
        }
        .foregroundColor(.gray)
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever()) { blink = true } }
        .padding(.leading, 10)
    }
}

extension View {
    func delay(_ delay: Double) -> some View {
        self.animation(Animation.easeInOut.delay(delay), value: UUID())
    }
}
