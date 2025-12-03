import SwiftUI
import PhotosUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - 持久化存储
    @AppStorage("selectedModel") var selectedModelId: String = "models/gemini-2.5-flash"
    @AppStorage("savedModels") var savedModelsData: Data = Data()
    
    // MARK: - 状态属性
    @Published var savedKeys: [SavedKey] = []
    @Published var currentKeyId: UUID?
    
    // 多会话管理
    @Published var sessions: [ChatSession] = []
    @Published var currentSessionId: UUID?
    
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    
    // 图片相关
    @Published var selectedImageItem: PhotosPickerItem? = nil
    @Published var selectedImageData: Data? = nil
    
    @Published var availableModels: [GeminiModelInfo] = []
    
    private let service = GeminiService()
    
    // MARK: - 初始化
    init() {
        loadKeys()
        loadSessions()
        
        if sessions.isEmpty {
            createNewSession()
        } else if currentSessionId == nil {
            currentSessionId = sessions.first?.id
        }
    }
    
    // MARK: - 会话管理 (Session Management)
    var currentMessages: [ChatMessage] {
        guard let sessionId = currentSessionId,
              let session = sessions.first(where: { $0.id == sessionId }) else {
            return []
        }
        return session.messages
    }
    
    func createNewSession() {
        let newSession = ChatSession(title: "新对话", messages: [], lastModified: Date())
        sessions.insert(newSession, at: 0)
        currentSessionId = newSession.id
        saveSessions()
    }
    
    func selectSession(_ session: ChatSession) {
        currentSessionId = session.id
    }
    
    func deleteSession(at offsets: IndexSet) {
        let idsToDelete = offsets.map { sessions[$0].id }
        sessions.remove(atOffsets: offsets)
        
        if let current = currentSessionId, idsToDelete.contains(current) {
            if let first = sessions.first {
                currentSessionId = first.id
            } else {
                createNewSession()
            }
        }
        saveSessions()
    }
    
    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "chatSessions_v1")
        }
    }
    
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: "chatSessions_v1"),
           let decoded = try? JSONDecoder().decode([ChatSession].self, from: data) {
            self.sessions = decoded.sorted(by: { $0.lastModified > $1.lastModified })
        }
    }
    
    private func updateCurrentSessionMessages(_ newMessages: [ChatMessage]) {
        guard let index = sessions.firstIndex(where: { $0.id == currentSessionId }) else { return }
        
        sessions[index].messages = newMessages
        sessions[index].lastModified = Date()
        
        // 自动更新标题
        if newMessages.count == 1, let firstText = newMessages.first?.text, !firstText.isEmpty {
            let title = String(firstText.prefix(10))
            sessions[index].title = title
        } else if sessions[index].title == "新对话" && !newMessages.isEmpty {
             if let firstUserMsg = newMessages.first(where: { $0.role == .user }) {
                 sessions[index].title = String(firstUserMsg.text.prefix(10))
             }
        }
        
        sessions.sort(by: { $0.lastModified > $1.lastModified })
        saveSessions()
    }
    
    // MARK: - API Key 管理
    func loadKeys() {
        if let data = UserDefaults.standard.data(forKey: "myApiKeys"),
           let keys = try? JSONDecoder().decode([SavedKey].self, from: data) {
            self.savedKeys = keys
            if currentKeyId == nil, let first = keys.first {
                currentKeyId = first.id
            }
        }
    }
    
    func addKey(key: String, label: String) {
        let finalLabel = label.isEmpty ? "Key \(savedKeys.count + 1)" : label
        let newKey = SavedKey(key: key, label: finalLabel)
        savedKeys.append(newKey)
        currentKeyId = newKey.id
        saveKeysToDisk()
    }
    
    func deleteKey(at offsets: IndexSet) {
        let idsToDelete = offsets.map { savedKeys[$0].id }
        savedKeys.remove(atOffsets: offsets)
        if let current = currentKeyId, idsToDelete.contains(current) {
            currentKeyId = savedKeys.first?.id
        }
        saveKeysToDisk()
    }
    
    func selectKey(id: UUID) {
        currentKeyId = id
    }
    
    private func saveKeysToDisk() {
        if let encoded = try? JSONEncoder().encode(savedKeys) {
            UserDefaults.standard.set(encoded, forKey: "myApiKeys")
        }
    }
    
    var activeApiKeyString: String {
        guard let id = currentKeyId else { return "" }
        return savedKeys.first(where: { $0.id == id })?.key ?? ""
    }
    
    // MARK: - 模型管理
    var savedModels: [GeminiModelInfo] {
        get {
            if let decoded = try? JSONDecoder().decode([GeminiModelInfo].self, from: savedModelsData) {
                return decoded
            }
            return []
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                savedModelsData = encoded
            }
        }
    }
    
    var currentModelName: String {
        return selectedModelId.replacingOccurrences(of: "models/", with: "")
    }
    
    func fetchOnlineModels() async {
        guard !activeApiKeyString.isEmpty else { return }
        do {
            let models = try await service.fetchModels(apiKey: activeApiKeyString)
            self.availableModels = models
        } catch {
            print("Fetch models error: \(error)")
        }
    }
    
    func addToFavorites(model: GeminiModelInfo) {
        var current = savedModels
        if !current.contains(where: { $0.id == model.id }) {
            current.append(model)
            savedModels = current
        }
    }
    
    // MARK: - 图片处理
    func loadImage() {
        Task {
            if let data = try? await selectedImageItem?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                if let compressed = uiImage.jpegData(compressionQuality: 0.3) {
                    self.selectedImageData = compressed
                }
            }
        }
    }
    
    // MARK: - 消息发送逻辑 (包含流式传输)
    func sendMessage() {
        let keyToUse = activeApiKeyString
        guard (!inputText.isEmpty || selectedImageData != nil) else { return }
        
        if currentSessionId == nil { createNewSession() }
        var msgs = currentMessages
        
        if keyToUse.isEmpty {
            msgs.append(ChatMessage(role: .model, text: "⚠️ 请先在设置中添加 API Key"))
            updateCurrentSessionMessages(msgs)
            return
        }
        
        let userMsg = ChatMessage(role: .user, text: inputText, imageData: selectedImageData)
        msgs.append(userMsg)
        updateCurrentSessionMessages(msgs)
        
        inputText = ""
        selectedImageItem = nil
        selectedImageData = nil
        isLoading = true
        
        // 预先插入一条空的 Model 消息，用于接收流式数据
        let botMsg = ChatMessage(role: .model, text: "")
        msgs.append(botMsg)
        updateCurrentSessionMessages(msgs)
        
        let botIndex = msgs.count - 1
        
        Task {
            let history = msgs.dropLast(1).suffix(10).map { $0 }
            var responseText = ""
            
            do {
                // 调用流式接口
                let stream = service.streamChat(messages: history, modelId: selectedModelId, apiKey: keyToUse)
                
                // 循环接收每一个字符 (打字机效果)
                for try await chunk in stream {
                    responseText += chunk
                    
                    // 实时更新当前会话
                    if var currentMsgs = sessions.first(where: { $0.id == currentSessionId })?.messages,
                       botIndex < currentMsgs.count {
                        currentMsgs[botIndex].text = responseText
                        updateCurrentSessionMessages(currentMsgs)
                    }
                }
            } catch {
                if var currentMsgs = sessions.first(where: { $0.id == currentSessionId })?.messages,
                   botIndex < currentMsgs.count {
                    if responseText.isEmpty {
                        currentMsgs[botIndex].text = "❌ 请求失败: \(error.localizedDescription)"
                    } else {
                        currentMsgs[botIndex].text += "\n\n[连接中断]"
                    }
                    updateCurrentSessionMessages(currentMsgs)
                }
            }
            
            isLoading = false
        }
    }
    
    func clearCurrentChat() {
        updateCurrentSessionMessages([])
    }
}
