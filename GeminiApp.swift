import SwiftUI

@main
struct GeminiApp: App { // 如果你的结构体名字叫 Gemini_Watch_AppApp，请不要改名，保持原样
    var body: some Scene {
        WindowGroup {
            ChatView()
        }
    }
}
