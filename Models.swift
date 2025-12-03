import Foundation

// 聊天角色
enum Role: String, Codable, Sendable {
    case user
    case model
}

// 消息结构
struct ChatMessage: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    let role: Role
    var text: String
    var imageData: Data? = nil
}

// 对话会话结构
struct ChatSession: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var messages: [ChatMessage]
    var lastModified: Date
}

// 模型列表响应 (这里就是报错的地方，现在纯净了)
struct ModelListResponse: Codable, Sendable {
    let models: [GeminiModelInfo]
}

struct GeminiModelInfo: Codable, Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let displayName: String?
    let supportedGenerationMethods: [String]?
    
    var shortName: String {
        return name.replacingOccurrences(of: "models/", with: "")
    }
}

// API Key 管理结构
struct SavedKey: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var key: String
    var label: String
}
