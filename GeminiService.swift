import Foundation
import UIKit // 用于 UIImage/Data 转换等，但不影响 Actor

class GeminiService: NSObject, URLSessionDelegate {
    
    private let defaultHost = "https://gemini.yamadaryo.me"
    
    // 自定义 URLSession
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120.0
        config.timeoutIntervalForResource = 300.0
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    // 忽略 SSL 证书错误 (TLS 验证失败修复)
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    // --- 核心修复：更安全的 URL 构建方式 (解决 404 问题) ---
    private func buildRequest(path: String, queryItems: [URLQueryItem]? = nil, apiKey: String) -> URLRequest? {
        let storedHost = UserDefaults.standard.string(forKey: "customHost") ?? defaultHost
        // 去除 host 结尾的斜杠
        let cleanHost = storedHost.hasSuffix("/") ? String(storedHost.dropLast()) : storedHost
        
        // 1. 尝试解析 Host
        guard var components = URLComponents(string: cleanHost) else { return nil }
        
        // 2. 拼接路径 (确保 /v1beta/ 不被重复，也不丢失)
        // 注意：path 传进来时可能是 "models" 也可能是 "models/gemini-pro:streamGenerateContent"
        // 我们不需要对 path 进行额外的 encoding，URLComponents 会帮我们处理基础的，
        // 但关键是保留冒号 : 和斜杠 /
        let basePath = "/v1beta/" + path
        components.path = basePath
        
        // 3. 处理参数 (主要是 ?alt=sse)
        if let queryItems = queryItems {
            components.queryItems = queryItems
        }
        
        // 4. 生成 URL
        // 这里的 url 属性会自动处理 ? 和 &，不会把它们搞坏
        guard let url = components.url else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        return request
    }

    // 获取模型列表
    func fetchModels(apiKey: String) async throws -> [GeminiModelInfo] {
        // GET 请求，没有额外参数
        guard var request = buildRequest(path: "models", apiKey: apiKey) else { throw URLError(.badURL) }
        request.httpMethod = "GET"
        
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(ModelListResponse.self, from: data)
        return response.models.filter { $0.supportedGenerationMethods?.contains("generateContent") ?? false }
    }

    // 流式对话
    func streamChat(messages: [ChatMessage], modelId: String, apiKey: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                // 1. 准备 Request Body
                let contents: [[String: Any]] = messages.map { msg in
                    var parts: [[String: Any]] = []
                    
                    if let imgData = msg.imageData {
                        parts.append([
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": imgData.base64EncodedString()
                            ]
                        ])
                    }
                    
                    if !msg.text.isEmpty {
                        parts.append(["text": msg.text])
                    }
                    
                    return [
                        "role": msg.role.rawValue,
                        "parts": parts
                    ]
                }
                
                let body: [String: Any] = ["contents": contents]
                
                // 2. 构建 URL (修复 404 的关键点)
                // Path: modelId + ":streamGenerateContent"
                // Query: alt=sse
                let path = "\(modelId):streamGenerateContent"
                let queryItems = [URLQueryItem(name: "alt", value: "sse")]
                
                guard var request = buildRequest(path: path, queryItems: queryItems, apiKey: apiKey) else {
                    continuation.finish(throwing: URLError(.badURL))
                    return
                }
                
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                
                do {
                    let (result, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: URLError(.badServerResponse))
                        return
                    }
                    
                    // 调试输出
                    if httpResponse.statusCode != 200 {
                         print("API Error: \(httpResponse.statusCode)")
                         continuation.yield(" [API 错误: \(httpResponse.statusCode) - 请检查模型是否支持或 Key 是否有效]")
                         continuation.finish(throwing: URLError(.badServerResponse))
                         return
                    }

                    // 3. 解析流
                    for try await line in result.lines {
                        guard !line.isEmpty else { continue }
                        
                        var jsonStr = line
                        if jsonStr.hasPrefix("data: ") {
                            jsonStr = String(jsonStr.dropFirst(6))
                        }
                        
                        if jsonStr.trimmingCharacters(in: .whitespaces) == "[DONE]" { continue }
                        
                        if let data = jsonStr.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let candidates = json["candidates"] as? [[String: Any]],
                           let content = candidates.first?["content"] as? [String: Any],
                           let parts = content["parts"] as? [[String: Any]],
                           let text = parts.first?["text"] as? String {
                            
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    print("Stream Error: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
