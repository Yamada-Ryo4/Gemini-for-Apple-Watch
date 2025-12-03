# Gemini for Apple Watch ⌚️🤖

<p align="center">
  <img src="https://img.shields.io/badge/Platform-watchOS-lightgrey.svg?style=flat" alt="Platform watchOS">
  <img src="https://img.shields.io/badge/Language-Swift-orange.svg?style=flat" alt="Language Swift">
  <img src="https://img.shields.io/badge/API-Google%20Gemini-blue.svg?style=flat" alt="Gemini API">
</p>

一个运行在 Apple Watch 上的原生 Gemini 客户端。支持流式对话、多会话管理、Markdown 渲染以及图片识别功能。

## ✨ 主要功能

*   **⚡️ 流式响应 (Streaming)**: 像打字机一样实时显示 AI 的回复，拒绝长时间等待。
*   **💬 多会话管理**: 支持新建对话、查看历史记录、自动根据对话内容生成标题。
*   **📝 Markdown 支持**: 完美渲染 **加粗**、*斜体*、[链接](https://google.com) 以及 `### 标题`。
*   **🖼️ 视觉能力**: 支持从手表相册选择图片发送给 Gemini 进行多模态对话。
*   **🔧 自定义配置**:
    *   支持管理多个 API Key。
    *   支持自定义代理 Host (解决网络访问问题)。
    *   支持切换不同模型 (Gemini Pro, Flash 等)。
*   **🚀 极致性能**: 基于 SwiftUI 和 Swift Concurrency (Async/Await) 构建，针对 watchOS 进行内存和网络优化。

## 📸 截图预览

| 对话界面 | 历史记录 | 发送图片 | 设置页面 |
|:---:|:---:|:---:|:---:|
| <img src="Assets/screenshot_chat.png" width="180" alt="Chat View"> | <img src="Assets/screenshot_history.png" width="180" alt="History View"> | <img src="Assets/screenshot_image.png" width="180" alt="Image Picker"> | <img src="Assets/screenshot_settings.png" width="180" alt="Settings"> |

*(注意：请将截图放入项目的 `Assets` 文件夹或替换上述链接)*

## 🛠️ 安装与运行

### 环境要求
*   **Xcode**: 15.0+
*   **watchOS**: 9.0+ (建议 watchOS 10)
*   **Swift**: 5.9+

### 编译步骤
1.  克隆本项目到本地：
    ```bash
    git clone https://github.com/你的用户名/GeminiWatchApp.git
    ```
2.  使用 Xcode 打开项目文件。
3.  在 `Signing & Capabilities` 中修改 **Team** 为你自己的 Apple ID 开发团队。
4.  修改 **Bundle Identifier** (如果需要)。
5.  选择目标设备为你的 Apple Watch 或模拟器。
6.  点击运行 (Cmd + R)。

## ⚙️ 配置说明

### 1. 获取 API Key
你需要一个 Google Gemini 的 API Key。前往 [Google AI Studio](https://aistudio.google.com/) 获取。

### 2. 在 App 中设置
App 采用 **BYOK (Bring Your Own Key)** 模式：
1.  打开手表 App，向右滑动或点击左上角进入 **设置**。
2.  点击 "添加新 Key"。
3.  输入你的 API Key 并保存。

### 3. 网络/代理设置 (可选)
如果你所在的地区无法直接访问 Google API：
1.  在设置页面的 "代理 Host" 一栏中填入你的反向代理地址。
2.  默认地址为：`https://gemini.yamadaryo.me` (仅供测试)。
3.  App 内置了自定义 `URLSession` 配置，支持自签名证书信任，防止 TLS 握手失败。

## 🏗️ 技术栈

*   **UI 框架**: SwiftUI (NavigationStack, ScrollViewReader, PhotosPicker)
*   **网络层**: URLSession, Server-Sent Events (SSE) 处理, AsyncThrowingStream
*   **架构**: MVVM (Model-View-ViewModel)
*   **并发**: Swift Structured Concurrency (@MainActor, Sendable)

## ⚠️ 免责声明

*   本项目是非官方的开源客户端，与 Google 无关。
*   请妥善保管你的 API Key，不要将其泄露给他人。
*   使用自定义代理服务时，请确保服务器的安全性。

## 📄 开源协议

MIT License
